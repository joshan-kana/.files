#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2154
# Nix injects the shared script path; it defines the transition arrays.
source "${WALLPAPER_COMMON:-$(dirname "$0")/wallpaper-common.sh}"
library="$HOME/wallpapers"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/linux-desktop/wallpapers"
runtime="${XDG_CONFIG_HOME:-$HOME/.config}/linux-desktop/runtime.json"
action="${1:-}"
output="${2:-all}"
if [ "$action" = thumbnail-animated ]; then
  image="$output"
  [ -f "$image" ] && [[ $image == /* ]] || exit 2
  case "${image,,}" in *.gif | *.mp4 | *.webm | *.mkv | *.mov) ;; *) exit 2 ;; esac
  # The selected item alone gets a short, muted cached motion
  # preview. No decoding or background player when the gallery is
  # closed or global reduced motion is active.
  cache="${XDG_CACHE_HOME:-$HOME/.cache}/linux-desktop/wallpaper-thumbnails"
  mkdir -p "$cache"
  key="$(printf '%s:%s' "$image" "$(stat -c '%Y:%s' "$image")" | sha256sum | cut -d' ' -f1)"
  thumb="$cache/$key-motion.gif"
  exec 9>"$cache/$key-motion.lock"
  flock 9
  if [ ! -s "$thumb" ]; then
    tmp="$(mktemp "$cache/.animated.XXXXXXXX.gif")"
    trap 'rm -f "$tmp"' EXIT
    ffmpeg -nostdin -v error -i "$image" -t 2.5 \
      -vf 'fps=8,scale=320:200:force_original_aspect_ratio=decrease:flags=fast_bilinear' \
      -loop 0 -y "$tmp"
    mv -f "$tmp" "$thumb"
  fi
  printf '%s\n' "$thumb"
  exit 0
fi
if [ "$action" = thumbnail ] || [ "$action" = poster ]; then
  image="$output"
  [ -f "$image" ] && [[ $image == /* ]] || exit 2
  # Full-screen posters are cached at source resolution as lossless
  # PNGs; only gallery thumbnails are deliberately downscaled.
  if [ "$action" = poster ]; then
    case "${image,,}" in
    *.png | *.jpg | *.jpeg | *.webp | *.bmp)
      printf '%s\n' "$image"
      exit 0
      ;;
    esac
  fi
  cache="${XDG_CACHE_HOME:-$HOME/.cache}/linux-desktop/wallpaper-thumbnails"
  mkdir -p "$cache"
  key="$(printf '%s:%s' "$image" "$(stat -c '%Y:%s' "$image")" | sha256sum | cut -d' ' -f1)"
  suffix=""
  [ "$action" != poster ] || suffix="-poster"
  thumb="$cache/$key$suffix.png"
  exec 8>"$cache/$key.lock"
  flock 8
  if [ ! -s "$thumb" ]; then
    tmp="$(mktemp "$cache/.thumb.XXXXXXXX.png")"
    trap 'rm -f "$tmp"' EXIT
    if [ "$action" = poster ]; then
      ffmpeg -nostdin -v error -i "$image" -frames:v 1 -update 1 -y "$tmp"
    else
      ffmpeg -nostdin -v error -i "$image" -frames:v 1 -vf 'scale=380:250:force_original_aspect_ratio=decrease' -update 1 -y "$tmp"
    fi
    mv -f "$tmp" "$thumb"
  fi
  printf '%s\n' "$thumb"
  exit 0
fi

case "$output" in
*[!a-zA-Z0-9_.-]* | "")
  printf 'Invalid output name: %s\n' "$output" >&2
  exit 2
  ;;
esac
state_file="$state_dir/$output.wall"

if [ "$action" = motion ]; then
  quiet="$XDG_RUNTIME_DIR/linux-desktop-wallpaper-motion-disabled"
  case "$output" in
  off) touch "$quiet" ;;
  on) rm -f "$quiet" ;;
  *) exit 2 ;;
  esac
  # Static selections don't change when animation is toggled.
  # Only animated wallpapers need reconfiguration to a still/video.
  default_video="$(jq -r '.wallpaperVideoDefault // empty' "$runtime" 2>/dev/null || true)"
  if [ -n "$default_video" ] && [ -f "$default_video" ]; then
    systemctl --user start --no-block linux-desktop-wallpaper-image.service
  fi
  for selection in "$state_dir"/*.wall; do
    [ -f "$selection" ] || continue
    image="$(tail -n 1 "$selection")"
    case "${image,,}" in
    *.gif | *.mp4 | *.webm | *.mkv | *.mov)
      systemctl --user start --no-block linux-desktop-wallpaper-image.service
      break
      ;;
    esac
  done
  exit 0
fi

case "$action" in
list)
  if [ -d "$library" ]; then
    # The personal library can be a directory symlink into a
    # mounted share (e.g. Parallels' Dropbox mapping). Follow
    # only the supplied root symlink, not arbitrary nested links.
    find -H "$library" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \) -print | LC_ALL=C sort | jq -Rsc '[split("\n")[] | select(length > 0)]'
  else
    printf '[]\n'
  fi
  ;;
current)
  # An all-output override also applies to screens that have no
  # more-specific override. Report the effective wallpaper, not
  # the Stylix default hidden beneath an active all-output image.
  current_file="$state_file"
  if [ ! -f "$current_file" ] && [ "$output" != all ]; then
    current_file="$state_dir/all.wall"
  fi
  if [ -f "$current_file" ]; then
    { IFS= read -r resize && IFS= read -r image; } <"$current_file" || exit 1
    printf '%s\n' "$image"
  else
    default_video="$(jq -r '.wallpaperVideoDefault // empty' "$runtime")"
    if [ -n "$default_video" ] && [ -f "$default_video" ]; then
      printf '%s\n' "$default_video"
    else
      jq -er '.wallpaper' "$runtime"
    fi
  fi
  ;;
set)
  resize="${3:-crop}"
  image="${4:-}"
  case "$resize" in crop | fit) ;; *)
    printf 'Invalid resize mode\n' >&2
    exit 2
    ;;
  esac
  case "${image,,}" in
  *.png | *.jpg | *.jpeg | *.webp | *.bmp | *.gif) kind=image ;;
  *.mp4 | *.webm | *.mkv | *.mov) kind=video ;;
  *)
    printf 'Unsupported wallpaper image: %s\n' "$image" >&2
    exit 2
    ;;
  esac
  if [ ! -f "$image" ] || [ "${image:0:1}" != / ]; then
    printf 'Wallpaper must be an existing absolute file path\n' >&2
    exit 2
  fi
  exec 9>"${XDG_RUNTIME_DIR:?}/linux-desktop-wallpaper.lock"
  flock -x 9
  wallpaper_transition
  unit="linux-desktop-wallpaper-video@$output.service"
  args=()
  [ "$output" = all ] || args=(--outputs "$output")
  previous_file="$state_dir/$output.wall"
  [ -f "$previous_file" ] || previous_file="$state_dir/all.wall"
  if [ -f "$previous_file" ]; then
    previous="$(tail -n 1 "$previous_file")"
    case "${previous,,}" in
    *.mp4 | *.webm | *.mkv | *.mov)
      # The video layer covers the image layer. Retain its poster
      # before stopping it, so the next image has a visible old frame.
      previous_poster="$($0 poster "$previous")"
      awww img "${args[@]}" --resize "$resize" --transition-type none "$previous_poster"
      ;;
    esac
  fi
  if [ "$kind" = video ]; then
    ffprobe -v error -select_streams v:0 -show_entries stream=codec_type -of csv=p=0 "$image" | grep -qx video || exit 2
    still="$($0 poster "$image")"
  else
    still="$image"
    if [ -f "$XDG_RUNTIME_DIR/linux-desktop-wallpaper-motion-disabled" ] && [[ ${image,,} == *.gif ]]; then
      still="$($0 poster "$image")"
    fi
  fi
  systemctl --user stop "$unit" || true
  if [ "$output" = all ]; then
    # Applying to all displays replaces earlier monitor-specific
    # selections. Stop their video layers before painting the new
    # wallpaper so they cannot hide the transition or playback.
    for selection in "$state_dir"/*.wall; do
      [ -f "$selection" ] && [ "$selection" != "$state_file" ] || continue
      monitor="$(basename "$selection" .wall)"
      systemctl --user stop "linux-desktop-wallpaper-video@$monitor.service" || true
    done
  fi
  awww img "${args[@]}" --resize "$resize" "${transition_args[@]}" "$still"
  mkdir -p "$state_dir"
  temp="$(mktemp "$state_dir/.wallpaper.XXXXXXXX")"
  trap 'rm -f "$temp"' EXIT
  printf '%s\n%s\n' "$resize" "$image" >"$temp"
  mv -f "$temp" "$state_file"
  if [ "$output" = all ]; then
    # Do not retain stale output overrides after an all-display
    # selection; later per-display choices can override it again.
    for selection in "$state_dir"/*.wall; do
      [ -f "$selection" ] && [ "$selection" != "$state_file" ] || continue
      rm -f "$selection"
    done
  elif [ -f "$state_dir/all.wall" ]; then
    # Recompute global video coverage after an override changes.
    case "$(tail -n 1 "$state_dir/all.wall")" in
    *.mp4 | *.webm | *.mkv | *.mov)
      systemctl --user restart linux-desktop-wallpaper-video@all.service || true
      ;;
    esac
  fi
  if [ "$kind" = video ]; then
    if [ ! -f "$XDG_RUNTIME_DIR/linux-desktop-wallpaper-motion-disabled" ]; then
      # Let the eased poster transition finish before playing the
      # same first frame as video, avoiding an abrupt hard swap.
      sleep "$wallpaper_transition_duration"
    fi
    if [ "$output" != all ] && [ -f "$state_dir/all.wall" ] && cmp -s "$state_file" "$state_dir/all.wall"; then
      systemctl --user stop "$unit" || true
    else
      systemctl --user restart "$unit"
    fi
  fi
  ;;
reset)
  systemctl --user stop "linux-desktop-wallpaper-video@$output.service" || true
  rm -f "$state_file"
  if [ "$output" != all ] && [ -f "$state_dir/all.wall" ]; then
    case "$(tail -n 1 "$state_dir/all.wall")" in
    *.mp4 | *.webm | *.mkv | *.mov)
      systemctl --user restart linux-desktop-wallpaper-video@all.service || true
      ;;
    esac
  fi
  systemctl --user start --no-block linux-desktop-wallpaper-image.service
  ;;
*)
  printf 'Usage: linux-desktop-wallpaper-library {list|current [output]|set output crop\|fit /abs/file|reset [output]|thumbnail /abs/file|poster /abs/file|thumbnail-animated /abs/file|motion on\|off}\n' >&2
  exit 2
  ;;
esac
