#!/usr/bin/env bash
set -euo pipefail

command="${1:-}"
resume=false
session="${HYPRLAND_INSTANCE_SIGNATURE:?Screen effects require an active Hyprland session}"
runtimeDir="${XDG_RUNTIME_DIR:?}/desktop-shell"
stateFile="$runtimeDir/vhs-state-$session"
pausedFile="$runtimeDir/screen-effects-paused-$session"
cacheDir="$runtimeDir/screen-compositions-$session"
umask 077
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

luaEscape() { sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

applyConfig() {
  local response
  response="$(hyprctl eval "$1")" || return 1
  [[ "$response" == ok ]] || {
    printf '%s\n' "$response" >&2
    return 1
  }
}

verifyConfig() {
  [[ "$(optionValue debug:damage_tracking int)" == "$1" &&
  "$(optionValue debug:vfr bool)" == "$2" &&
  "$(optionValue decoration:screen_shader str)" == "$3" ]]
}

managedShader() {
  [[ "$1" == "$cacheDir/"* || "$1" == "$runtimeDir/vhs.frag/"* ||
    "$1" == "$runtimeDir/crt.frag/"* || "$1" == "$runtimeDir/hologram.frag/"* ||
    "$1" == "$runtimeDir/glitch.frag/"* || "$1" == "$runtimeDir/film.frag/"* ||
    "$1" == "$runtimeDir/monochrome.frag/"* ]]
}

restoreOriginal() {
  if [[ ! -f "$stateFile" ]]; then
    local current
    current="$(optionValue decoration:screen_shader str)"
    if managedShader "$current"; then
      applyConfig 'hl.config({ decoration = { screen_shader = "" } })'
      [[ "$(optionValue decoration:screen_shader str)" == "" ]]
    fi
    return
  fi
  local -a values
  mapfile -t values <"$stateFile"
  local damage="${values[0]:-}" vfr="${values[1]:-}" shader="${values[2]:-}"
  [[ "$damage" =~ ^[012]$ && "$vfr" =~ ^(true|false)$ ]] || {
    echo "Invalid saved compositor state; refusing to overwrite it" >&2
    return 1
  }
  local escaped
  escaped="$(printf '%s' "$shader" | luaEscape)"
  applyConfig "hl.config({ debug = { damage_tracking = $damage, vfr = $vfr }, decoration = { screen_shader = \"$escaped\" } })"
  verifyConfig "$damage" "$vfr" "$shader" || return 1
  rm -f "$stateFile"
}

case "$command" in
resume)
  [[ $# == 1 ]] || exit 2
  rm -f "$pausedFile"
  exit 0
  ;;
emergency-off)
  [[ $# == 1 ]] || exit 2
  printf 'suspended\n' >"$pausedFile"
  restoreOriginal
  exit 0
  ;;
off)
  [[ $# == 1 ]] || exit 2
  restoreOriginal
  exit 0
  ;;
apply)
  [[ $# == 2 ]] || {
    echo "Expected one JSON composition" >&2
    exit 2
  }
  resume="$(jq -r '.resume == true' <<<"$2")"
  [[ ! -f "$pausedFile" || "$resume" == true ]] || exit 0
  ;;
*)
  echo "Usage: desktop-shell-vhs apply <JSON> | off | resume | emergency-off" >&2
  exit 2
  ;;
esac

export SCREEN_COMPOSITE_CACHE="$cacheDir"
result="$(python3 "${SCREEN_COMPOSITOR_GENERATOR:?}" "$2")" || exit 2
if [[ "$result" == off ]]; then
  restoreOriginal
  if [[ "$resume" == true ]]; then
    rm -f "$pausedFile"
  fi
  exit 0
fi
read -r shader animation <<<"$result"
[[ -f "$shader" && "$shader" == "$cacheDir/"* && "$animation" =~ ^(animated|static)$ ]] || exit 2

# Generate and validate before changing the compositor.
glslangValidator -S frag "$shader" >/dev/null || {
  echo "Composed shader failed GLSL validation; keeping previous shader" >&2
  exit 1
}

oldDamage="$(optionValue debug:damage_tracking int)"
oldVfr="$(optionValue debug:vfr bool)"
oldShader="$(optionValue decoration:screen_shader str)"
[[ "$oldDamage" =~ ^[012]$ && "$oldVfr" =~ ^(true|false)$ ]] || exit 1

newState=false
if [[ ! -f "$stateFile" ]]; then
  originalState="$(mktemp "$stateFile.XXXXXX")"
  trap 'rm -f "$originalState"' EXIT
  printf '%s\n%s\n%s\n' "$oldDamage" "$oldVfr" "$oldShader" >"$originalState"
  mv "$originalState" "$stateFile"
  newState=true
fi

if [[ "$animation" == animated ]]; then
  damage=0
  vfr=false
else
  damage="$(sed -n '1p' "$stateFile")"
  vfr="$(sed -n '2p' "$stateFile")"
fi

escaped="$(printf '%s' "$shader" | luaEscape)"
if ! applyConfig "hl.config({ debug = { damage_tracking = $damage, vfr = $vfr }, decoration = { screen_shader = \"$escaped\" } })" ||
  ! verifyConfig "$damage" "$vfr" "$shader"; then
  oldEscaped="$(printf '%s' "$oldShader" | luaEscape)"
  applyConfig "hl.config({ debug = { damage_tracking = $oldDamage, vfr = $oldVfr }, decoration = { screen_shader = \"$oldEscaped\" } })" || true
  verifyConfig "$oldDamage" "$oldVfr" "$oldShader" || echo "Compositor rollback could not be verified" >&2
  [[ "$newState" != true ]] || rm -f "$stateFile"
  exit 1
fi
if [[ "$resume" == true ]]; then
  rm -f "$pausedFile"
fi
