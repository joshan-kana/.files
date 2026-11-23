#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
if [[ "$mode" != on && "$mode" != off ]]; then
  printf 'Usage: desktop-shell-vhs on <intensity 0..100> | off\n' >&2
  exit 2
fi

session="${HYPRLAND_INSTANCE_SIGNATURE:?VHS requires an active Hyprland session}"
runtimeDir="${XDG_RUNTIME_DIR:?}/desktop-shell"
stateFile="$runtimeDir/vhs-state-$session"
umask 077

optionValue() {
  local option="$1" type="$2" line
  while IFS= read -r line; do
    if [[ "$line" == "$type: "* ]]; then
      printf '%s\n' "${line#"$type: "}"
      return 0
    fi
  done < <(hyprctl getoption "$option")
  return 1
}

luaEscape() {
  sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

if [[ "$mode" == off ]]; then
  if [[ ! -e "$stateFile" ]]; then
    # Preserve an unrelated user-configured screen shader. Also clean up
    # the original static VHS shader when upgrading in a running session.
    currentShader="$(optionValue decoration:screen_shader str)" || exit 0
    if [[ "$currentShader" == "$runtimeDir/"* ]]; then
      exec hyprctl eval 'hl.config({ decoration = { screen_shader = "" } })'
    fi
    exit 0
  fi

  mapfile -t saved <"$stateFile"
  damage="${saved[0]:-}"
  vfr="${saved[1]:-}"
  shader="${saved[2]:-}"
  if ! [[ "$damage" =~ ^[012]$ && "$vfr" =~ ^(true|false)$ ]]; then
    printf 'Cannot restore compositor: invalid VHS state\n' >&2
    exit 1
  fi

  escapedShader="$(printf '%s' "$shader" | luaEscape)"
  hyprctl eval "hl.config({ debug = { damage_tracking = $damage, vfr = $vfr }, decoration = { screen_shader = \"$escapedShader\" } })"
  rm -f "$stateFile"
  exit 0
fi

level="${2:-}"
if ! [[ "$level" =~ ^([0-9]|[1-9][0-9]|100)$ ]]; then
  printf 'VHS intensity must be an integer from 0 to 100\n' >&2
  exit 2
fi

# An enabled zero-intensity effect should not waste cycles on a full-screen
# animated compositor pass.
if [[ "$level" == 0 ]]; then
  exec bash "$0" off
fi

shaderSource="${VHS_SHADER_SOURCE:?VHS shader source not configured}"
mkdir -p "$runtimeDir"
shaderDir="$runtimeDir/$(basename "$shaderSource")"
mkdir -p "$shaderDir"
shader="$shaderDir/$(printf '%03d' "$level").frag"
if [[ ! -f "$shader" ]]; then
  printf -v intensity '%d.%02d' "$((10#$level / 100))" "$((10#$level % 100))"
  temporary="$(mktemp "$shader.XXXXXX")"
  trap 'rm -f "$temporary"' EXIT
  sed "s/^const float VHS_INTENSITY = .*;/const float VHS_INTENSITY = $intensity;/" "$shaderSource" >"$temporary"
  mv "$temporary" "$shader"
fi

if [[ ! -e "$stateFile" ]]; then
  originalDamage="$(optionValue debug:damage_tracking int)"
  originalVfr="$(optionValue debug:vfr bool)"
  originalShader="$(optionValue decoration:screen_shader str)"
  if ! [[ "$originalDamage" =~ ^[012]$ && "$originalVfr" =~ ^(true|false)$ ]]; then
    printf 'Cannot enable VHS: failed to read compositor settings\n' >&2
    exit 1
  fi
  previous="$(mktemp "$stateFile.XXXXXX")"
  trap 'rm -f "$previous"' EXIT
  printf '%s\n%s\n%s\n' "$originalDamage" "$originalVfr" "$originalShader" >"$previous"
  mv "$previous" "$stateFile"
fi

escapedShader="$(printf '%s' "$shader" | luaEscape)"
# Time-based animation needs continuous redraws even while the desktop is idle.
# Restore the exact previous settings when turning the effect off.
hyprctl eval "hl.config({ debug = { damage_tracking = 0, vfr = false }, decoration = { screen_shader = \"$escapedShader\" } })"
