#!/usr/bin/env bash
action="${1:-}"
id="${2:-}"
private_dir="${XDG_RUNTIME_DIR:?}/linux-desktop-clipboard"
case "$action" in
clear)
  # The thumbnails are disposable previews, never a second store.
  rm -rf -- "$private_dir"
  ;;
image)
  [[ $id =~ ^[0-9]+$ ]] || exit 2
  umask 077
  mkdir -p -- "$private_dir"
  chmod 700 -- "$private_dir"
  # Only one thumbnail is ever retained; frequent J/K navigation
  # must not leave a growing set of decoded private images behind.
  find "$private_dir" -maxdepth 1 -type f -name 'preview-*.png' -delete
  tmp="$(mktemp "$private_dir/preview-XXXXXXXX.png")"
  trap 'rm -f -- "$tmp"' EXIT
  if cliphist decode "$id" | magick \
    -limit memory 96MiB -limit map 192MiB \
    -limit width 8192 -limit height 8192 \
    - -auto-orient -thumbnail '520x340>' -strip "png:$tmp"; then
    printf '%s\n' "$tmp"
    # QML removes all thumbnail files on panel dismissal.
    trap - EXIT
  else
    exit 1
  fi
  ;;
*) exit 2 ;;
esac
