#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
bridge="$root/scripts/kibby-touchpad-state"
fixture="$root/tests/fixtures/caelestia"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[[ -x "$bridge" ]] || fail "missing executable state bridge: $bridge"
bash -n "$bridge"

test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
export XDG_RUNTIME_DIR="$test_root/runtime"
export CAELESTIA_BIN="$fixture"
export CAELESTIA_TEST_LOG="$test_root/toasts.log"

"$bridge" disabled
[[ $(<"$XDG_RUNTIME_DIR/kibby/touchpad-state") == disabled ]] || fail "disabled state was not persisted"
[[ $(<"$CAELESTIA_TEST_LOG") == 'shell toaster info Touchpad locked The built-in touchpad is disabled mouse' ]] || fail "disabled toast arguments differ"

"$bridge" enabled
[[ $(<"$XDG_RUNTIME_DIR/kibby/touchpad-state") == enabled ]] || fail "enabled state was not persisted"
[[ $(tail -n 1 "$CAELESTIA_TEST_LOG") == 'shell toaster success Touchpad unlocked The built-in touchpad is enabled mouse' ]] || fail "enabled toast arguments differ"

line_count=$(wc -l < "$CAELESTIA_TEST_LOG")
"$bridge" disabled --quiet
[[ $(wc -l < "$CAELESTIA_TEST_LOG") -eq "$line_count" ]] || fail "quiet mode emitted a toast"

if "$bridge" broken >/dev/null 2>&1; then
    fail "invalid state was accepted"
fi
[[ $(<"$XDG_RUNTIME_DIR/kibby/touchpad-state") == disabled ]] || fail "invalid state changed persisted state"

rg -Fq 'property bool touchpadEnabled: true' "$root/services/Hypr.qml" || fail "Hypr touchpad state property is absent"
rg -Fq 'path: `${Quickshell.env("XDG_RUNTIME_DIR")}/kibby/touchpad-state`' "$root/services/Hypr.qml" || fail "touchpad state path is absent"
rg -Fq 'watchChanges: true' "$root/services/Hypr.qml" || fail "touchpad state is not watched"
rg -Fq 'onFileChanged: reload()' "$root/services/Hypr.qml" || fail "touchpad state does not reload"
rg -Fq '&& Hypr.touchpadEnabled' "$root/modules/bar/components/StatusIcons.qml" || fail "status container ignores touchpad state"
rg -Fq 'implicitWidth: present ? (item?.implicitWidth ?? 0) : 0' "$root/modules/bar/components/StatusIcons.qml" || fail "collapsed status entry still reserves its width"
rg -Fq 'implicitHeight: present ? (item?.implicitHeight ?? 0) : 0' "$root/modules/bar/components/StatusIcons.qml" || fail "collapsed status entry still reserves its height"
rg -Fq 'text: "mouse"' "$root/modules/bar/components/status/LockStatus.qml" || fail "persistent touchpad icon is absent"
if rg -Fq 'touchpad_off' "$root/scripts/kibby-touchpad-state" "$root/modules/bar/components/status/LockStatus.qml"; then
    fail "unsupported touchpad_off glyph is still used"
fi
rg -Fq 'Hypr.touchpadEnabled ? "Enabled" : "Disabled"' "$root/modules/bar/popouts/LockStatus.qml" || fail "touchpad popout state is absent"

printf 'PASS: touchpad state bridge, toasts, watcher, status icon, and popout\n'
