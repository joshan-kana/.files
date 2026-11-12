#!/usr/bin/env bash
# shellcheck disable=SC2034 # Shared arrays and values are consumed by callers.
# Shared transition settings for wallpaper services and gallery operations.
wallpaper_transition_duration=1.05
wallpaper_transition() {
  transition_args=(
    --transition-type wave
    --transition-angle 28
    --transition-wave "24,10"
    --transition-duration "$wallpaper_transition_duration"
    --transition-fps 120
    --transition-bezier "0.2,0,0.15,1"
  )
  if [ -f "${XDG_RUNTIME_DIR:?}/linux-desktop-wallpaper-motion-disabled" ]; then
    transition_args=(--transition-type none)
  fi
}
