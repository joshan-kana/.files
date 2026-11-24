#!/usr/bin/env bash
screenshot_dir="$(desktop-shell-capture-locations get screenshots)" || exit 1
mode="${1:-}"
private_dir="${XDG_RUNTIME_DIR:?}"
ensure_snapshot() {
  [[ $1 == "$private_dir"/desktop-shell-capture-*.png ]] && [ -f "$1" ] && [ ! -L "$1" ]
}
case "$mode" in
snapshot)
  { [ "$#" -eq 2 ] || [ "$#" -eq 3 ]; } && [ -n "$2" ] || exit 2
  args=()
  cursor="${3:-}"
  if [ -z "$cursor" ]; then
    case "$(capture_default cursor)" in true) cursor=cursor ;; false) cursor=no-cursor ;; *) exit 2 ;; esac
  fi
  case "$cursor" in cursor) args+=(-c) ;; no-cursor) ;; *) exit 2 ;; esac
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
  if [ "$#" -eq 8 ]; then
    format="$7"
    quality="$8"
  else
    format="$(capture_default imageFormat)" || exit 2
    quality="$(capture_default jpegQuality)" || exit 2
  fi
  capture_validate imageFormat "$format" jpegQuality "$quality" || exit 2
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
  dest="$screenshot_dir"
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
