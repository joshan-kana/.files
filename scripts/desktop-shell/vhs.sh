#!/usr/bin/env bash
set -euo pipefail
mode="${1:-}"
case "$mode" in
off)
  exec hyprctl eval 'hl.config({ decoration = { screen_shader = "" } })'
  ;;
on) ;;
*)
  printf 'Usage: desktop-shell-vhs on <intensity 0..100> | off\n' >&2
  exit 2
  ;;
esac
level="${2:-}"
if ! [[ "$level" =~ ^([0-9]|[1-9][0-9]|100)$ ]]; then
  printf 'VHS intensity must be an integer from 0 to 100\n' >&2
  exit 2
fi
shaderDir="${XDG_RUNTIME_DIR:?}/desktop-shell/$(basename "$VHS_SHADER_SOURCE")"
umask 077
mkdir -p "$shaderDir"
shader="$shaderDir/$(printf '%03d' "$level").frag"
if [[ ! -f "$shader" ]]; then
  printf -v intensity '%d.%02d' "$((10#$level / 100))" "$((10#$level % 100))"
  temporary="$(mktemp "$shader.XXXXXX")"
  trap 'rm -f "$temporary"' EXIT
  sed "s/^const float VHS_INTENSITY = .*;/const float VHS_INTENSITY = $intensity;/" "$VHS_SHADER_SOURCE" >"$temporary"
  mv "$temporary" "$shader"
fi
exec hyprctl eval "hl.config({ decoration = { screen_shader = \"$shader\" } })"
