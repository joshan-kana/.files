# shellcheck shell=bash
# Evaluated Nix defaults and supported values are supplied by the wrapper.
capture_default() {
  jq -er --arg key "$1" '.[$key] | select(. != null) | tostring' <<<"${DESKTOP_CAPTURE_DEFAULTS:?}"
}

capture_validate() {
  while [ "$#" -gt 0 ]; do
    jq -e --arg key "$1" --arg value "$2" '.[$key].values | map(tostring) | index($value) != null' <<<"${DESKTOP_CAPTURE_CONSTRAINTS:?}" >/dev/null || return 1
    shift 2
  done
}
