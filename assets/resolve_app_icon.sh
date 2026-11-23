#!/bin/sh

icon_name=$1
[ -n "$icon_name" ] || exit 0

icon_path=$(/usr/bin/kiconfinder6 "$icon_name" 2>/dev/null) || exit 0
[ -n "$icon_path" ] || exit 0

printf '%s\t%s\n' "$icon_name" "$icon_path"
