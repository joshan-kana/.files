#!/usr/bin/env bash
settings="${XDG_RUNTIME_DIR:?}/linux-desktop-recording.conf"
if [ -f "$settings" ]; then
  { IFS= read -r output && IFS= read -r geometry && IFS= read -r audio; } <"$settings" || exit 2
  rm -f -- "$settings"
  [[ $output =~ ^[a-zA-Z0-9_.-]+$ ]] || exit 2
  [[ $geometry =~ ^-?[0-9]+,-?[0-9]+\ [0-9]+x[0-9]+$ ]] || exit 2
  case "$audio" in none | system | microphone) ;; *) exit 2 ;; esac
  args=(--output "$output")
else
  # Explicit live-select alternative for callers outside the hub.
  geometry="$(slurp -d)" || exit 0
  audio=none
  args=()
fi
[ -n "$geometry" ] || exit 0
directory="${LINUX_DESKTOP_RECORDING_DIR:-$HOME/Videos/Screencasts}"
mkdir -p "$directory"
output="$directory/Recording-$(date +%Y%m%d-%H%M%S)-$$.mp4"
case "$audio" in
system)
  sink="$(pactl get-default-sink)"
  [ -n "$sink" ] || exit 2
  args+=("--audio=${sink}.monitor")
  ;;
microphone)
  source="$(pactl get-default-source)"
  [ -n "$source" ] || exit 2
  args+=("--audio=$source")
  ;;
esac
printf 'recording\n%s\n%s\n' "$(date +%s)" "$output" >"${XDG_RUNTIME_DIR:?}/linux-desktop-recording.state"
exec wf-recorder "${args[@]}" --geometry "$geometry" --file "$output"
