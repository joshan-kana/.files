#!/usr/bin/env bash
[ "$#" -eq 2 ] || exit 2
case "$1" in
screenshot | edit-screenshot)
  path="$2"
  name="${path##*/}"
  dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
  [[ $name =~ ^Screenshot-[0-9]{8}-[0-9]{6}-[0-9]+\.png$ ]] || exit 2
  [[ $path == "$dir/$name" ]] || exit 2
  ;;
recording | edit-recording)
  name="$2"
  [[ $name =~ ^Recording-[0-9]{8}-[0-9]{6}-[0-9]+\.mp4$ ]] || exit 2
  path="$HOME/Videos/Screencasts/$name"
  ;;
*) exit 2 ;;
esac
[ -f "$path" ] && [ ! -L "$path" ] || exit 1
case "$1" in
edit-screenshot) exec linux-desktop-markup "$path" ;;
edit-recording) exec losslesscut --disable-networking "$path" ;;
esac
exec xdg-open "$path"
