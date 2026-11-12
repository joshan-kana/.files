#!/usr/bin/env bash
output="${1:?Output required}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/linux-desktop/wallpapers"
file="$state_dir/$output.wall"
if [ -r "$file" ]; then
  { IFS= read -r resize && IFS= read -r video; } <"$file" || exit 1
elif [ "$output" = all ]; then
  runtime="${XDG_CONFIG_HOME:-$HOME/.config}/linux-desktop/runtime.json"
  video="$(jq -r '.wallpaperVideoDefault // empty' "$runtime")"
  [ -n "$video" ] || exit 0
  resize=fit
else
  exit 0
fi
[ -f "$video" ] || exit 1
case "${video,,}" in *.mp4 | *.webm | *.mkv | *.mov) ;; *) exit 0 ;; esac
[ ! -f "$XDG_RUNTIME_DIR/linux-desktop-wallpaper-motion-disabled" ] || exit 0
options='no-audio loop-file=inf hwdec=auto'
[ "$resize" != crop ] || options="$options panscan=1"
if [ "$output" != all ]; then
  exec mpvpaper -p -a full -l background -o "$options" "$output" "$video"
fi

# The all-display selection is a default, not another layer over a
# monitor override. A wildcard player could obscure newer video
# selections after a theme switch changed service restart order.
outputs=""
for _ in {1..25}; do
  if outputs="$(awww query 2>/dev/null)"; then break; fi
  sleep 0.2
done
[ -n "$outputs" ] || exit 1
pids=()
while IFS= read -r line; do
  [[ $line == ': '* ]] || continue
  monitor="${line#: }"
  monitor="${monitor%%:*}"
  [ -n "$monitor" ] || continue
  if [ -f "$state_dir/$monitor.wall" ] && { [ ! -f "$file" ] || ! cmp -s "$file" "$state_dir/$monitor.wall"; }; then
    continue
  fi
  mpvpaper -p -a full -l background -o "$options" "$monitor" "$video" &
  pids+=("$!")
done <<<"$outputs"
[ "${#pids[@]}" -gt 0 ] || exit 0
trap 'kill "${pids[@]}" 2>/dev/null || true' EXIT
# Relaunch the coverage set if any player exits unexpectedly.
wait -n "${pids[@]}" || true
exit 1
