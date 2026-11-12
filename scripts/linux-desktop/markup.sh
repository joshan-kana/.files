#!/usr/bin/env bash
[ "$#" -le 1 ] || exit 2
if [ "$#" -eq 0 ]; then
  selected="$(kdialog --getopenfilename "$HOME/Pictures" 'Images (*.png *.jpg *.jpeg *.webp *.bmp *.gif)')" || exit 0
  [ -n "$selected" ] || exit 0
  set -- "$selected"
fi
[ -f "$1" ] && [ -r "$1" ] || exit 2
case "$(file --brief --mime-type -- "$1")" in image/*) ;; *) exit 2 ;; esac
umask 077
dest="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p -- "$dest"
output="$dest/Screenshot-$(date +%Y%m%d-%H%M%S)-$$.png"
exec satty --filename "$1" --output-filename "$output" \
  --copy-command wl-copy --initial-tool arrow --no-window-decoration \
  --font-family monospace \
  --save-after-copy --actions-on-enter save-to-clipboard \
  --actions-on-escape exit --early-exit all
