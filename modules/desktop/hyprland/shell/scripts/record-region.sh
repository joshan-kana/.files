#!/usr/bin/env bash
recording_dir="$(desktop-shell-capture-locations get recordings)" || exit 1
umask 077
settings="${XDG_RUNTIME_DIR:?}/desktop-shell-recording.conf"
format="$(capture_default videoFormat)" || exit 2
codec="$(capture_default codec)" || exit 2
fps="$(capture_default frameRate)" || exit 2
quality="$(capture_default videoQuality)" || exit 2
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
  args=(--output "$output")
else
  # Explicit live-select alternative for callers outside the hub.
  geometry="$(slurp -d)" || exit 0
  audio="$(capture_default audio)" || exit 2
  args=()
fi
[ -n "$geometry" ] || exit 0
capture_validate videoFormat "$format" codec "$codec" frameRate "$fps" videoQuality "$quality" audio "$audio" || exit 2
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
