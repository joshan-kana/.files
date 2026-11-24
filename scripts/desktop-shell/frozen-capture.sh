#!/usr/bin/env bash
mode="${1:-}"
private_dir="${XDG_RUNTIME_DIR:?}"
ensure_snapshot() {
  [[ $1 == "$private_dir"/desktop-shell-capture-*.png ]] && [ -f "$1" ] && [ ! -L "$1" ]
}
case "$mode" in
snapshot)
   { [ "$#" -eq 2 ] || [ "$#" -eq 3 ]; } && [ -n "$2" ] || exit 2
  args=()
  case "${3:-no-cursor}" in cursor) args+=(-c) ;; no-cursor) ;; *) exit 2 ;; esac
  umask 077
  snapshot="$(mktemp "$private_dir/desktop-shell-capture-XXXXXXXX.png")"
  if grim "${args[@]}" -o "$2" "$snapshot"; then printf '%s\n' "$snapshot"; else
    rm -f -- "$snapshot"
    exit 1
  fi
  ;;
clear)
  [ "$#" -eq 2 ] && ensure_snapshot "$2" || exit 2
  rm -f -- "$2"
  ;;
copy | save | annotate)
   { [ "$#" -eq 6 ] || [ "$#" -eq 8 ]; } && ensure_snapshot "$2" || exit 2
  format="${7:-png}"
  quality="${8:-95}"
  case "$format" in png | jpg) ;; *) exit 2 ;; esac
  case "$quality" in 75 | 85 | 95) ;; *) exit 2 ;; esac
  # The markup pipeline and clipboard require lossless source pixels.
  if [ "$mode" != save ]; then format=png; fi
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
  output="$dest/Screenshot-$(date +%Y%m%d-%H%M%S)-$$.$format"
  options=()
  if [ "$format" = jpg ]; then options+=(-quality "$quality"); fi
  magick "$2" -crop "$geometry" +repage -strip "${options[@]}" "$output"
  if [ "$mode" = copy ]; then
    wl-copy --type image/png <"$output" || exit 1
  fi
  systemd-run --user --quiet --collect -- desktop-shell-capture-notify screenshot "$output" || true
  if [ "$mode" = annotate ]; then
    desktop-shell-markup "$output"
  fi
  printf '%s\n' "$output"
  # Keep the source available for retry if either export fails.
  rm -f -- "$2"
  ;;
*) exit 2 ;;
esac
