#!/usr/bin/env bash
# Shared transition settings for wallpaper services and gallery operations.
wallpaper_transition_duration=1.05
# shellcheck disable=SC2329 # Only image entry points invoke the shared transition.
wallpaper_transition() {
  # shellcheck disable=SC2034 # This array is consumed by wallpaper entry points.
  transition_args=(
    --transition-type wave
    --transition-angle 28
    --transition-wave "24,10"
    --transition-duration "$wallpaper_transition_duration"
    --transition-fps 120
    --transition-bezier "0.2,0,0.15,1"
  )
  if [ -f "${XDG_RUNTIME_DIR:?}/desktop-shell-wallpaper-motion-disabled" ]; then
    # shellcheck disable=SC2034 # This array is consumed by wallpaper entry points.
    transition_args=(--transition-type none)
  fi
}

wallpaper_default_resize() {
  jq -er '.appearance.wallpaperResizeMode | select(. == "fit" or . == "crop")' "$1"
}
