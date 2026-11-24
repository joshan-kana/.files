#!/usr/bin/env bash
[ "$#" -eq 2 ] || exit 2
kind="$1"
file="$2"
case "$kind" in
screenshot)
  choice="$(notify-send --app-name=desktop-shell --icon=image-x-generic \
    --hint="string:image-path:$file" --action=default=Open \
    --action=text="Select text" --action=copy=Copy --action=edit=Markup \
    "Screenshot saved" "$file")" || exit 0
  ;;
recording)
  choice="$(notify-send --app-name=desktop-shell --icon=video-x-generic \
    --action=default=Open --action=text="Select text" --action=edit=Trim \
    "Recording saved" "$(basename -- "$file")")" || exit 0
  ;;
*) exit 2 ;;
esac
case "$choice" in
default) exec desktop-shell-open-capture "$kind" "$([ "$kind" = recording ] && basename -- "$file" || printf '%s\n' "$file")" ;;
edit) exec desktop-shell-open-capture "edit-$kind" "$([ "$kind" = recording ] && basename -- "$file" || printf '%s\n' "$file")" ;;
text) exec desktop-shell-open-capture "text-$kind" "$([ "$kind" = recording ] && basename -- "$file" || printf '%s\n' "$file")" ;;
copy) [ "$kind" = screenshot ] && exec desktop-shell-recordings copy "$(basename -- "$file")" ;;
esac
