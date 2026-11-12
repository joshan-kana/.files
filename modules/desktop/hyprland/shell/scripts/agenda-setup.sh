#!/usr/bin/env bash
configRoot="${XDG_CONFIG_HOME:-$HOME/.config}/khal"
dataRoot="${XDG_DATA_HOME:-$HOME/.local/share}/calendars/personal"
configFile="$configRoot/config"
if [ -e "$configFile" ]; then
  printf 'Existing khal configuration preserved: %s\n' "$configFile"
  exit 0
fi
mkdir -p "$configRoot" "$dataRoot"
cat >"$configFile" <<EOF
[calendars]
[[personal]]
path = $dataRoot
type = calendar

[default]
default_calendar = personal

[locale]
timeformat = %H:%M
dateformat = %Y-%m-%d
longdateformat = %Y-%m-%d
datetimeformat = %Y-%m-%d %H:%M
longdatetimeformat = %Y-%m-%d %H:%M
EOF
