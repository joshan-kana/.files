#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
if [[ "$mode" != on && "$mode" != off ]]; then
  printf 'Usage: desktop-shell-vhs on <intensity percent> [tracking chroma noise scanlines speed dropouts] | off\n' >&2
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

if [[ -z "${2:-}" ]] || (($# > 8)); then
  printf 'VHS requires an intensity and accepts at most seven parameters\n' >&2
  exit 2
fi

# The compositor accepts whole percentages. Defaults and allowed ranges come
# from the same evaluated appearance options as the shell controls.
if ! resolved="$(jq -ern \
  --argjson defaults "${DESKTOP_VHS_DEFAULTS:?}" \
  --argjson constraints "${DESKTOP_VHS_CONSTRAINTS:?}" '
    $ARGS.positional as $arguments
    | ["vhsIntensity", "vhsTracking", "vhsChroma", "vhsNoise", "vhsScanlines", "vhsSpeed", "vhsDropouts"]
    | to_entries[]
    | .value as $name
    | ($arguments[.key] // "") as $argument
    | (if $argument == "" then ($defaults[$name] * 100 | round)
       elif $argument | test("^(0|[1-9][0-9]*)$") then $argument | tonumber
       else error("Invalid VHS percentage for " + $name) end) as $percent
    | $constraints[$name] as $rule
    | if $rule == null or $percent / 100 < $rule.min or $percent / 100 > $rule.max
      then error("VHS percentage outside declared range for " + $name)
      else $percent end
  ' --args "${@:2}")"; then
  exit 2
fi
mapfile -t values <<<"$resolved"
level="${values[0]}"
tracking="${values[1]}"
chroma="${values[2]}"
noise="${values[3]}"
scanlines="${values[4]}"
speed="${values[5]}"
dropouts="${values[6]}"

# An enabled zero-intensity effect should not waste cycles on a full-screen
# animated compositor pass.
if [[ "$level" == 0 ]]; then
  exec bash "$0" off
fi

shaderSource="${VHS_SHADER_SOURCE:?VHS shader source not configured}"
mkdir -p "$runtimeDir"
shaderDir="$runtimeDir/$(basename "$shaderSource")"
mkdir -p "$shaderDir"
printf -v shaderName '%03d-%03d-%03d-%03d-%03d-%03d-%03d.frag' "$level" "$tracking" "$chroma" "$noise" "$scanlines" "$speed" "$dropouts"
shader="$shaderDir/$shaderName"
if [[ ! -f "$shader" ]]; then
  filters=()
  names=(INTENSITY TRACKING CHROMA NOISE SCANLINES SPEED DROPOUTS)
  for index in "${!names[@]}"; do
    amount="${values[index]}"
    printf -v strength '%d.%02d' "$((amount / 100))" "$((amount % 100))"
    filters+=(-e "s/^const float VHS_${names[index]} = .*;/const float VHS_${names[index]} = $strength;/")
  done
  temporary="$(mktemp "$shader.XXXXXX")"
  trap 'rm -f "$temporary"' EXIT
  sed "${filters[@]}" "$shaderSource" >"$temporary"
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
