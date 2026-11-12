#!/usr/bin/env bash
mode="${1:-}"
private_dir="${XDG_RUNTIME_DIR:?}"
ensure_snapshot() {
  [[ $1 == "$private_dir"/linux-desktop-capture-*.png ]] && [ -f "$1" ] && [ ! -L "$1" ]
}
case "$mode" in
snapshot)
  [ "$#" -eq 2 ] && [ -n "$2" ] || exit 2
  umask 077
  snapshot="$(mktemp "$private_dir/linux-desktop-capture-XXXXXXXX.png")"
  if grim -o "$2" "$snapshot"; then printf '%s\n' "$snapshot"; else
    rm -f -- "$snapshot"
    exit 1
  fi
  ;;
clear)
  [ "$#" -eq 2 ] && ensure_snapshot "$2" || exit 2
  rm -f -- "$2"
  ;;
copy | save | annotate)
  [ "$#" -eq 6 ] && ensure_snapshot "$2" || exit 2
  for number in "$3" "$4" "$5" "$6"; do [[ $number =~ ^[0-9]+$ ]] || exit 2; done
  x="$3"
  y="$4"
  w="$5"
  h="$6"
  [ "$w" -gt 0 ] && [ "$h" -gt 0 ] || exit 2
  read -r full_width full_height < <(magick identify -format '%w %h\n' "$2")
  [ "$((x + w))" -le "$full_width" ] && [ "$((y + h))" -le "$full_height" ] || exit 2
  # Preserve the frozen frame on export failure so Enter can retry.
  geometry="${w}x${h}+${x}+${y}"
  umask 077
  dest="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
  mkdir -p -- "$dest"
  output="$dest/Screenshot-$(date +%Y%m%d-%H%M%S)-$$.png"
  magick "$2" -crop "$geometry" +repage -strip "$output"
  if [ "$mode" = copy ]; then
    wl-copy --type image/png <"$output"
  fi
  systemd-run --user --quiet --collect -- linux-desktop-capture-notify screenshot "$output" || true
  if [ "$mode" = annotate ]; then
    linux-desktop-markup "$output"
  fi
  printf '%s\n' "$output"
  # Keep the source available for retry if either export fails.
  rm -f -- "$2"
  ;;
*) exit 2 ;;
esac
