#!/usr/bin/env bash
set -euo pipefail

fail() {
  notify-send -a 'Workspace scratchpad' 'Unavailable' "$1"
  exit 1
}

case "${1:-}" in
  toggle)
    workspace=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .activeWorkspace.id')
    [[ "$workspace" =~ ^[1-9][0-9]*$ ]] || fail 'No regular workspace is focused.'
    hyprctl dispatch "hl.dsp.workspace.toggle_special(\"local-$workspace\")" >/dev/null
    ;;
  move)
    window=$(hyprctl -j activewindow)
    address=$(jq -r '.address // empty' <<<"$window")
    [[ "$address" =~ ^0x[[:xdigit:]]+$ ]] || fail 'No movable window is focused.'
    [[ $(jq -r '.floating' <<<"$window") == false ]] || fail 'Only tiled windows can be parked.'
    [[ $(jq -r '.fullscreen' <<<"$window") == 0 ]] || fail 'Leave fullscreen before parking a window.'
    [[ $(jq -r '.pinned' <<<"$window") == false ]] || fail 'Unpin the window before parking it.'

    workspace=$(jq -r '.workspace.name' <<<"$window")
    case "$workspace" in
      special:local-*)
        destination=${workspace#special:local-}
        [[ "$destination" =~ ^[1-9][0-9]*$ ]] || fail 'Cannot identify the original workspace.'
        ;;
      *)
        destination=$(jq -r '.workspace.id' <<<"$window")
        [[ "$destination" =~ ^[1-9][0-9]*$ ]] || fail 'This window is not on a regular workspace.'
        destination="special:local-$destination"
        ;;
    esac
    hyprctl dispatch "hl.dsp.window.move({ workspace = \"$destination\", window = \"address:$address\", follow = false })" >/dev/null
    ;;
  *)
    printf 'Usage: linux-desktop-local-scratchpad {move|toggle}\n' >&2
    exit 2
    ;;
esac
