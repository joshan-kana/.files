#!/usr/bin/env bash
# Native autocopy loses ownership when the transient action exits.
# A separate clipboard scope keeps the selected text pasteable until
# another app replaces it, without any permanently running service.
selected="$(hyprpicker --format=hex --no-fancy)" || exit 0
if ! [[ $selected =~ ^#[[:xdigit:]]{6}$ ]]; then
  printf 'Unexpected colour picker result\n' >&2
  exit 1
fi
# shellcheck disable=SC2016
systemd-run --user --scope --quiet -- \
  bash -c 'printf "%s" "$1" | wl-copy --type text/plain' colour-picker-copy "$selected"
notify-send --app-name=linux-desktop "Colour copied" "$selected"
