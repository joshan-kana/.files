#!/usr/bin/env bash
state="${XDG_RUNTIME_DIR:?}/linux-desktop-recording.state"
[ -r "$state" ] || exit 0
{ IFS= read -r previous && IFS= read -r started && IFS= read -r savedPath; } <"$state" || exit 0
[[ $savedPath == /*/Recording-*.mp4 ]] || exit 0
case "$previous" in recording | finalising) ;; *) exit 0 ;; esac
if [ -s "$savedPath" ] && ffprobe -v error -select_streams v:0 -show_entries stream=codec_type -of csv=p=0 "$savedPath" | grep -qx video; then
  printf 'completed\n%s\n%s\n' "$started" "$savedPath" >"$state"
  systemd-run --user --quiet --collect -- linux-desktop-capture-notify recording "$savedPath" || true
else
  printf 'failed\n%s\n%s\n' "$started" "$savedPath" >"$state"
  notify-send --app-name=linux-desktop -u critical "Recording failed" "Could not finalise the selected capture" || true
fi
