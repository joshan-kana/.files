#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
effect="vhs"
# All compositor-wide effects share the same saved original state. Switching
# kinds must never mistake the previous effect for the original user shader.
case "$mode" in
on | off) ;;
crt | hologram | glitch | film | monochrome)
  effect="$mode"
  mode=on
  ;;
*)
  printf 'Usage: desktop-shell-vhs on <intensity> [tracking chroma noise scanlines speed dropouts] | crt|hologram|glitch|film|monochrome <seven percentages> | off\n' >&2
  exit 2
  ;;
esac

session="${HYPRLAND_INSTANCE_SIGNATURE:?VHS requires an active Hyprland session}"
runtimeDir="${XDG_RUNTIME_DIR:?}/desktop-shell"
stateFile="$runtimeDir/vhs-state-$session"
umask 077
# One authoritative compositor state transaction across rapid effect switches.
# Locking is outside the shader cache so concurrent invocations cannot save
# another active effect as the original user-provided screen shader.
mkdir -p "$runtimeDir"
exec 9>"$runtimeDir/screen-effects.lock"
flock -x 9

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

applyConfig() {
  local reply
  reply="$(hyprctl eval "$1")" || return 1
  if [[ "$reply" != ok ]]; then
    printf '%s\n' "$reply" >&2
    return 1
  fi
}

verifyConfig() {
  [[ "$(optionValue debug:damage_tracking int)" == "$1" &&
  "$(optionValue debug:vfr bool)" == "$2" &&
  "$(optionValue decoration:screen_shader str)" == "$3" ]]
}

# Do not clear another application's shader when the original state is lost.
isManagedShader() {
  local source
  for source in "$VHS_SHADER_SOURCE" "$SCREEN_CRT_SOURCE" "$SCREEN_HOLOGRAM_SOURCE" "$SCREEN_GLITCH_SOURCE" "$SCREEN_FILM_SOURCE" "$SCREEN_MONOCHROME_SOURCE"; do
    [[ "$currentShader" == "$runtimeDir/$(basename "$source")/"* ]] && return 0
  done
  return 1
}

restoreOriginal() {
  if [[ ! -e "$stateFile" ]]; then
    # Preserve an unrelated user-configured screen shader. Also clean up
    # the original static VHS shader when upgrading in a running session.
    currentShader="$(optionValue decoration:screen_shader str)" || exit 1
    if isManagedShader; then
      applyConfig 'hl.config({ decoration = { screen_shader = "" } })'
      [[ "$(optionValue decoration:screen_shader str)" == "" ]] || exit 1
    fi
    return 0
  fi

  mapfile -t saved <"$stateFile"
  damage="${saved[0]:-}"
  vfr="${saved[1]:-}"
  shader="${saved[2]:-}"
  if ! [[ "$damage" =~ ^[012]$ && "$vfr" =~ ^(true|false)$ ]]; then
    printf 'Cannot restore compositor: invalid VHS state\n' >&2
    return 1
  fi

  escapedShader="$(printf '%s' "$shader" | luaEscape)"
  applyConfig "hl.config({ debug = { damage_tracking = $damage, vfr = $vfr }, decoration = { screen_shader = \"$escapedShader\" } })"
  verifyConfig "$damage" "$vfr" "$shader"
  rm -f "$stateFile"
  return 0
}

if [[ "$mode" == off ]]; then
  restoreOriginal
  exit 0
fi

if [[ -z "${2:-}" ]] || (($# > 8)); then
  printf 'VHS requires an intensity and accepts at most seven parameters\n' >&2
  exit 2
fi

# The compositor accepts whole percentages. Both effect families inherit their
# own evaluated Nix baselines and validation bounds.
if [[ "$effect" == vhs ]]; then
  defaults="${DESKTOP_VHS_DEFAULTS:?}"
  bounds="${DESKTOP_VHS_CONSTRAINTS:?}"
  keys='["vhsIntensity","vhsTracking","vhsChroma","vhsNoise","vhsScanlines","vhsSpeed","vhsDropouts"]'
  names=(INTENSITY TRACKING CHROMA NOISE SCANLINES SPEED DROPOUTS)
  prefix=VHS
else
  defaults="$(jq -cn --arg mode "$effect" --argjson defaults "${SCREEN_EFFECT_DEFAULTS:?}" '$defaults[$mode]')"
  bounds="${SCREEN_EFFECT_CONSTRAINTS:?}"
  keys='["intensity","shape","color","texture","lines","speed","artifacts"]'
  names=(INTENSITY SHAPE COLOR TEXTURE LINES SPEED ARTIFACTS)
  prefix=FX
fi
if ! resolved="$(jq -ern \
  --argjson defaults "$defaults" \
  --argjson constraints "$bounds" \
  --argjson keys "$keys" '
    $ARGS.positional as $arguments
    | $keys
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
  restoreOriginal
  exit 0
fi

case "$effect" in
vhs) shaderSource="${VHS_SHADER_SOURCE:?VHS shader source not configured}" ;;
crt) shaderSource="${SCREEN_CRT_SOURCE:?CRT shader source not configured}" ;;
hologram) shaderSource="${SCREEN_HOLOGRAM_SOURCE:?Hologram shader source not configured}" ;;
glitch) shaderSource="${SCREEN_GLITCH_SOURCE:?Glitch shader source not configured}" ;;
film) shaderSource="${SCREEN_FILM_SOURCE:?Film shader source not configured}" ;;
monochrome) shaderSource="${SCREEN_MONOCHROME_SOURCE:?Monochrome shader source not configured}" ;;
esac
mkdir -p "$runtimeDir"
shaderDir="$runtimeDir/$(basename "$shaderSource")"
mkdir -p "$shaderDir"
printf -v shaderName '%03d-%03d-%03d-%03d-%03d-%03d-%03d.frag' "$level" "$tracking" "$chroma" "$noise" "$scanlines" "$speed" "$dropouts"
shader="$shaderDir/$shaderName"
if [[ ! -f "$shader" ]]; then
  filters=()
  for index in "${!names[@]}"; do
    amount="${values[index]}"
    printf -v strength '%d.%02d' "$((amount / 100))" "$((amount % 100))"
    filters+=(-e "s/^const float ${prefix}_${names[index]} = .*;/const float ${prefix}_${names[index]} = $strength;/")
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
# Monochrome contains no time-based components. Keep the original compositor
# scheduling policy instead of forcing continuous redraws for a static shader.
if [[ "$effect" == monochrome ]]; then
  savedDamage="$(sed -n '1p' "$stateFile")"
  savedVfr="$(sed -n '2p' "$stateFile")"
  applyConfig "hl.config({ debug = { damage_tracking = $savedDamage, vfr = $savedVfr }, decoration = { screen_shader = \"$escapedShader\" } })"
  verifyConfig "$savedDamage" "$savedVfr" "$shader"
else
  applyConfig "hl.config({ debug = { damage_tracking = 0, vfr = false }, decoration = { screen_shader = \"$escapedShader\" } })"
  verifyConfig 0 false "$shader"
fi
