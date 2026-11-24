#!/usr/bin/env bash
[ "$#" -eq 2 ] || exit 2
case "$1" in
screenshot | edit-screenshot | text-screenshot)
  path="$2"
  name="${path##*/}"
  dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
  [[ $name =~ ^Screenshot-[0-9]{8}-[0-9]{6}-[0-9]+\.(png|jpg)$ ]] || exit 2
  [[ $path == "$dir/$name" ]] || exit 2
  ;;
recording | edit-recording | text-recording)
  name="$2"
  [[ $name =~ ^Recording-[0-9]{8}-[0-9]{6}-[0-9]+\.(mp4|mkv)$ ]] || exit 2
  path="${DESKTOP_SHELL_RECORDING_DIR:-$HOME/Videos/Screencasts}/$name"
  ;;
*) exit 2 ;;
esac
[ -f "$path" ] && [ ! -L "$path" ] || exit 1
case "$1" in
edit-screenshot) exec desktop-shell-markup "$path" ;;
edit-recording) exec losslesscut --disable-networking "$path" ;;
text-screenshot | text-recording)
  exec quickshell ipc --path "$DESKTOP_SHELL_SHELL_PATH" call desktop showCaptureText "$name"
  ;;
esac
exec xdg-open "$path"
