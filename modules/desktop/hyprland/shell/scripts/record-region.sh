#!/usr/bin/env bash
# All capture producers and readers resolve the same effective directories.
recording_dir="${DESKTOP_SHELL_RECORDING_DIR:-$HOME/Videos/Screencasts}"
if command -v desktop-shell-capture-locations >/dev/null 2>&1; then
  recording_dir="$(desktop-shell-capture-locations get recordings)" || exit 1
fi
umask 077
settings="${XDG_RUNTIME_DIR:?}/desktop-shell-recording.conf"
format=mp4
codec=libx264
fps=0
quality=23
if [ -f "$settings" ]; then
  mapfile -t configuration <"$settings"
  [ "${#configuration[@]}" -eq 3 ] || [ "${#configuration[@]}" -eq 7 ] || exit 2
  output="${configuration[0]}"
  geometry="${configuration[1]}"
  audio="${configuration[2]}"
  if [ "${#configuration[@]}" -eq 7 ]; then
    format="${configuration[3]}"
    codec="${configuration[4]}"
    fps="${configuration[5]}"
    quality="${configuration[6]}"
  fi
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
case "$format" in mp4 | mkv) ;; *) exit 2 ;; esac
case "$codec" in libx264 | libx265) ;; *) exit 2 ;; esac
case "$fps" in 0 | 30 | 60 | 120) ;; *) exit 2 ;; esac
case "$quality" in 18 | 23 | 28) ;; *) exit 2 ;; esac
args+=(--codec "$codec" --codec-param "crf=$quality")
if [ "$fps" -ne 0 ]; then args+=(--framerate "$fps"); fi
directory="$recording_dir"
mkdir -p "$directory"
output="$directory/Recording-$(date +%Y%m%d-%H%M%S)-$$.$format"
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
printf 'recording\n%s\n%s\n' "$(date +%s)" "$output" >"${XDG_RUNTIME_DIR:?}/desktop-shell-recording.state"
exec wf-recorder "${args[@]}" --geometry "$geometry" --file "$output"
