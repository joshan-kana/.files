#!/usr/bin/env bash
action="${1:-}"
recordings="$HOME/Videos/Screencasts"
preview_dir="${XDG_RUNTIME_DIR:?}/linux-desktop-recordings-preview"
case "$action" in
list)
  umask 077
  metadata_dir="${XDG_RUNTIME_DIR:?}/linux-desktop-recordings-metadata"
  [ ! -L "$metadata_dir" ] || exit 2
  mkdir -p -- "$metadata_dir"
  chmod 700 -- "$metadata_dir"
  {
    if [ -d "$recordings" ]; then
      while IFS=$'\t' read -r modified name size; do
        [[ $name =~ ^Recording-[0-9]{8}-[0-9]{6}-[0-9]+\.mp4$ ]] || continue
        path="$recordings/$name"
        [ -f "$path" ] && [ ! -L "$path" ] || continue
        key="$(printf '%s|%s|%s' "$name" "$modified" "$size" | sha256sum | cut -d' ' -f1)"
        metadata="$metadata_dir/$key"
        if [ ! -s "$metadata" ]; then
          duration="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$path" || true)"
          [[ $duration =~ ^[0-9]+(\.[0-9]+)?$ ]] || duration=0
          tmp="$(mktemp "$metadata_dir/.duration-XXXXXXXX")"
          printf '%s\n' "$duration" >"$tmp"
          mv -- "$tmp" "$metadata"
        fi
        read -r duration <"$metadata"
        printf '%s\t%s\t%s\t%s\n' "$modified" "$name" "$size" "$duration"
      done < <(find "$recordings" -maxdepth 1 -type f -regextype posix-extended \
        -regex '.*/Recording-[0-9]{8}-[0-9]{6}-[0-9]+\.mp4' -printf '%T@\t%f\t%s\n')
    fi
    screenshots="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
    if [ -d "$screenshots" ]; then
      while IFS=$'\t' read -r modified name size; do
        [[ $name =~ ^Screenshot-[0-9]{8}-[0-9]{6}-[0-9]+\.png$ ]] || continue
        printf '%s\t%s\t%s\t0\n' "$modified" "$name" "$size"
      done < <(find "$screenshots" -maxdepth 1 -type f -regextype posix-extended \
        -regex '.*/Screenshot-[0-9]{8}-[0-9]{6}-[0-9]+\.png' -printf '%T@\t%f\t%s\n')
    fi
  } | sort -rn | sed -n '1,100p'
  ;;
clear-preview)
  [ ! -L "$preview_dir" ] || exit 2
  rm -rf -- "$preview_dir"
  ;;
preview | open | edit | copy | trash)
  [ "$#" -eq 2 ] || exit 2
  name="$2"
  if [[ $name =~ ^Recording-[0-9]{8}-[0-9]{6}-[0-9]+\.mp4$ ]]; then
    path="$recordings/$name"
    kind=recording
  elif [[ $name =~ ^Screenshot-[0-9]{8}-[0-9]{6}-[0-9]+\.png$ ]]; then
    path="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots/$name"
    kind=image
  else
    exit 2
  fi
  [ -f "$path" ] && [ ! -L "$path" ] || exit 2
  if [ "$action" = open ]; then
    exec xdg-open "$path"
  elif [ "$action" = edit ]; then
    if [ "$kind" = image ]; then exec linux-desktop-markup "$path"; fi
    exec losslesscut --disable-networking "$path"
  elif [ "$action" = copy ]; then
    [ "$kind" = image ] || exit 2
    exec wl-copy --type image/png <"$path"
  elif [ "$action" = trash ]; then
    exec gio trash "$path"
  fi
  if [ "$kind" = image ]; then
    printf '%s\n' "$path"
    exit 0
  fi
  [ ! -L "$preview_dir" ] || exit 2
  umask 077
  mkdir -p -- "$preview_dir"
  chmod 700 -- "$preview_dir"
  find "$preview_dir" -maxdepth 1 -type f -name 'recording-*.png' -delete
  output="$(mktemp "$preview_dir/recording-XXXXXXXX.png")"
  trap 'rm -f -- "$output"' EXIT
  ffmpeg -hide_banner -loglevel error -ss 0.2 -i "$path" \
    -vf 'scale=510:300:force_original_aspect_ratio=decrease' \
    -frames:v 1 -y "$output" >/dev/null
  printf '%s\n' "$output"
  trap - EXIT
  ;;
*) exit 2 ;;
esac
