#!/usr/bin/env bash
[ "$#" -eq 2 ] || exit 2
kind="$1"
file="$2"
case "$kind" in
screenshot)
  choice="$(notify-send --app-name=linux-desktop --icon=image-x-generic \
    --hint="string:image-path:$file" --action=default=Open \
    --action=edit=Markup "Screenshot saved" "$file")" || exit 0
  ;;
recording)
  choice="$(notify-send --app-name=linux-desktop --icon=video-x-generic \
    --action=default=Open --action=edit=Trim \
    "Recording saved" "$(basename -- "$file")")" || exit 0
  ;;
*) exit 2 ;;
esac
case "$choice" in
default) exec linux-desktop-open-capture "$kind" "$([ "$kind" = recording ] && basename -- "$file" || printf '%s\n' "$file")" ;;
edit) exec linux-desktop-open-capture "edit-$kind" "$([ "$kind" = recording ] && basename -- "$file" || printf '%s\n' "$file")" ;;
esac
