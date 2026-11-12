#!/usr/bin/env bash
set -euo pipefail
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/linux-desktop"
state_file="$state_dir/night-light"
mode=off
temperature=4500
if [ -r "$state_file" ]; then
  read -r mode temperature <"$state_file" || true
fi
case "$mode" in off | manual | auto) ;; *) mode=off ;; esac
if ! [[ $temperature =~ ^[0-9]+$ ]]; then temperature=4500; fi
if ((temperature < 2500 || temperature > 6500)); then
  temperature=4500
fi
persist() {
  mkdir -p "$state_dir"
  temp_state="$(mktemp --tmpdir="$state_dir" night-light-XXXXXXXX)"
  printf '%s %s\n' "$mode" "$temperature" >"$temp_state"
  chmod 600 "$temp_state"
  mv -f "$temp_state" "$state_file"
}
# Preserve the current effective state when migrating an older
# automatic schedule to manual-only control.
if [ "$mode" = auto ]; then
  hour="$(date +%H)"
  if ((10#$hour >= 19 || 10#$hour < 7)); then
    mode=manual
  else
    mode=off
  fi
  persist
fi
should_run() {
  [ "$mode" = manual ]
}
apply() {
  if should_run; then
    systemctl --user restart linux-desktop-night-light.service
  else
    systemctl --user stop linux-desktop-night-light.service
  fi
}
case "${1:-state}" in
state)
  active=false
  if systemctl --user --quiet is-active linux-desktop-night-light.service; then active=true; fi
  printf '{"mode":"%s","temperature":%s,"active":%s,"supported":true}\n' "$mode" "$temperature" "$active"
  ;;
run)
  exec hyprsunset --temperature "$temperature"
  ;;
apply)
  apply
  ;;
toggle)
  if [ "$mode" = manual ]; then mode=off; else mode=manual; fi
  persist
  apply
  ;;
set)
  [ "$#" -eq 2 ] && [[ $2 =~ ^[0-9]+$ ]] || exit 2
  temperature="$2"
  ((temperature >= 2500 && temperature <= 6500)) || exit 2
  persist
  if should_run; then apply; fi
  ;;
warmer | cooler)
  if [ "$1" = warmer ]; then temperature=$((temperature - 500)); else temperature=$((temperature + 500)); fi
  temperature=$((temperature < 2500 ? 2500 : temperature > 6500 ? 6500 : temperature))
  persist
  if should_run; then apply; fi
  ;;
*)
  printf 'Usage: linux-desktop-night-light {state|run|apply|toggle|set K|warmer|cooler}\n' >&2
  exit 2
  ;;
esac
