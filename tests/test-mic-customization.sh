#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
toggle="$root/scripts/kibby-mic-toggle"
fixture_dir="$root/tests/fixtures"
integration=${1:-$HOME/.config/hypr/kibby/caelestia.lua}
shell_config=${2:-$HOME/.config/caelestia/shell.json}

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[[ -x "$toggle" ]] || fail "missing executable mic toggle: $toggle"
bash -n "$toggle"

test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
export WPCTL_BIN="$fixture_dir/wpctl"
export WPCTL_TEST_STATE="$test_root/mic-state"
export WPCTL_TEST_LOG="$test_root/wpctl.log"
export CAELESTIA_BIN="$fixture_dir/caelestia"
export CAELESTIA_TEST_LOG="$test_root/toasts.log"

printf 'unmuted\n' > "$WPCTL_TEST_STATE"
"$toggle"
[[ $(<"$WPCTL_TEST_STATE") == muted ]] || fail "first toggle did not mute the source"
[[ $(tail -n 1 "$CAELESTIA_TEST_LOG") == 'shell toaster info Microphone muted Your microphone is off mic_off' ]] || fail "muted toast arguments differ"

"$toggle"
[[ $(<"$WPCTL_TEST_STATE") == unmuted ]] || fail "second toggle did not unmute the source"
[[ $(tail -n 1 "$CAELESTIA_TEST_LOG") == 'shell toaster success Microphone unmuted Your microphone is on mic' ]] || fail "unmuted toast arguments differ"

[[ $(rg -c '^set-mute @DEFAULT_AUDIO_SOURCE@ toggle$' "$WPCTL_TEST_LOG") -eq 2 ]] || fail "default source was not toggled exactly twice"
[[ $(rg -c '^get-volume @DEFAULT_AUDIO_SOURCE@$' "$WPCTL_TEST_LOG") -eq 2 ]] || fail "resulting mute state was not read exactly twice"

before_toasts=$(wc -l < "$CAELESTIA_TEST_LOG")
export WPCTL_TEST_FAIL_SET=1
if "$toggle" >/dev/null 2>&1; then
    fail "wpctl toggle failure was ignored"
fi
[[ $(wc -l < "$CAELESTIA_TEST_LOG") -eq "$before_toasts" ]] || fail "toggle failure emitted a misleading toast"

rg -Fq "hl.dsp.exec_cmd(\"$HOME/.local/bin/kibby-mic-toggle\")" "$integration" || fail "hardware mic key does not use the tested toggle"
jq -e '.osd.enableMicrophone == true' "$shell_config" >/dev/null || fail "right-side microphone slider is not enabled"

printf 'PASS: mic key toggles the default source, emits accurate toasts, and enables the native slider\n'
