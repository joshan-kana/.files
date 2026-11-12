#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2154
# Nix injects the shared script path; it defines the transition arrays.
source "${WALLPAPER_COMMON:-$(dirname "$0")/wallpaper-common.sh}"
exec 9>"${XDG_RUNTIME_DIR:?}/linux-desktop-wallpaper.lock"
flock -n 9 || exit 0

# The default wallpaper belongs to the evaluated Stylix theme, not
# the runtime shortcuts/tools config. Restore saved display overrides
# independently of a custom default so video selections survive boot.
theme="${XDG_CONFIG_HOME:-$HOME/.config}/linux-desktop/theme.json"
runtime="${XDG_CONFIG_HOME:-$HOME/.config}/linux-desktop/runtime.json"
wallpaper="$(jq -er '.wallpaper | select(type == "string" and length > 0)' "$theme")"
default_video="$(jq -r '.wallpaperVideoDefault // empty' "$runtime" 2>/dev/null || true)"
[ -f "$default_video" ] || default_video=""

if [ ! -f "$wallpaper" ]; then
  printf 'Wallpaper does not exist: %s\n' "$wallpaper" >&2
  exit 1
fi

# The service can start before the Wayland daemon has opened its socket.
for _ in {1..25}; do
  if awww query >/dev/null 2>&1; then
    quiet="$XDG_RUNTIME_DIR/linux-desktop-wallpaper-motion-disabled"
    wallpaper_transition
    # Resolve overrides before painting. Applying Stylix to all
    # outputs first flashes over the user's selected wallpaper.
    state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/linux-desktop/wallpapers"
    if [ ! -f "$state_dir/all.wall" ]; then
      # A declarative video is the fallback for uncovered displays, not
      # another wildcard player competing with gallery selections.
      default_still="$wallpaper"
      if [ -n "$default_video" ]; then
        default_still="$(linux-desktop-wallpaper-library poster "$default_video")"
      fi
      while IFS= read -r output; do
        [ -n "$output" ] || continue
        if [ ! -f "$state_dir/$output.wall" ]; then
          if [ -n "$default_video" ]; then
            awww img --outputs "$output" --transition-type none "$default_still"
          else
            awww img --outputs "$output" "${transition_args[@]}" "$wallpaper"
          fi
        fi
      done < <(awww query | sed -n 's/^: \([^:]*\):.*/\1/p')
      if [ -n "$default_video" ] && [ ! -f "$quiet" ]; then
        systemctl --user restart --no-block linux-desktop-wallpaper-video@all.service
      else
        systemctl --user stop --no-block linux-desktop-wallpaper-video@all.service || true
      fi
    fi

    # Reapply each selected output without an intermediate default.
    for entry in "$state_dir"/*.wall; do
      [ -f "$entry" ] || continue
      { IFS= read -r resize && IFS= read -r image; } <"$entry" || continue
      [ -f "$image" ] || continue
      output="$(basename "$entry" .wall)"
      # A saved display selection identical to the all-display
      # selection needs no second image or video layer. In
      # particular, do not decode the same mp4 twice at login.
      if [ "$output" != all ] && [ -f "$state_dir/all.wall" ] && cmp -s "$entry" "$state_dir/all.wall"; then
        systemctl --user stop --no-block "linux-desktop-wallpaper-video@$output.service" || true
        continue
      fi
      args=()
      [ "$output" = all ] || args=(--outputs "$output")
      case "${image,,}" in
      *.mp4 | *.webm | *.mkv | *.mov)
        still="$(linux-desktop-wallpaper-library poster "$image")" || continue
        awww img "${args[@]}" --resize "$resize" --transition-type none "$still"
        if [ -f "$quiet" ]; then
          systemctl --user stop --no-block "linux-desktop-wallpaper-video@$output.service" || true
        else
          systemctl --user start --no-block "linux-desktop-wallpaper-video@$output.service"
        fi
        ;;
      *)
        still="$image"
        if [ -f "$quiet" ] && [[ ${image,,} == *.gif ]]; then
          still="$(linux-desktop-wallpaper-library poster "$image")" || continue
        fi
        awww img "${args[@]}" --resize "$resize" "${transition_args[@]}" "$still"
        ;;
      esac
    done
    exit 0
  fi
  sleep 0.2
done

printf 'awww daemon is not ready\n' >&2
exit 1
