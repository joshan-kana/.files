#!/usr/bin/env bash
# shellcheck disable=SC2154 # Entry-point variables are supplied by the Nix wrapper.
set_phase() {
  mkdir -p "$operationDir"
  chmod 700 "$operationDir"
  printf '%s\n' "$1" >"$operationDir/phase"
}

finish_operation() {
  result=$?
  if [ "$result" -eq 0 ]; then
    set_phase completed
  elif [ "$(cat "$operationDir/phase" 2>/dev/null || :)" != cancelled ]; then
    set_phase failed
  fi
}

validate_theme() {
  jq -e --arg selected "$1" '.themes | any(.name == $selected)' "$manifest" >/dev/null || {
    printf 'Unknown theme: %s\n' "$1" >&2
    exit 2
  }
}

case "${1:-}" in
list)
  if [ "${2:-}" = "--json" ]; then
    cat "$manifest"
  else
    jq -r '.themes[].name' "$manifest"
  fi
  ;;
current)
  printf '%s\n' "$configuredTheme"
  ;;
status)
  phase="$(cat "$operationDir/phase" 2>/dev/null || printf idle)"
  target="$(cat "$operationDir/target" 2>/dev/null || :)"
  active=false
  if systemctl --user --quiet is-active "$operationUnit"; then active=true; fi
  jq -n --arg phase "$phase" --arg target "$target" --argjson running "$active" '{phase:$phase,target:$target,running:$running}'
  ;;
logs)
  if [ -f "$operationDir/output.log" ]; then tail -n 12 "$operationDir/output.log" | cut -c1-150; fi
  ;;
cancel)
  mkdir -p "$operationDir"
  exec 9>"$operationDir/operation.lock"
  flock -x 9
  phase="$(cat "$operationDir/phase" 2>/dev/null || :)"
  if [ "$phase" != building ] && [ "$phase" != preparing ]; then
    flock -u 9
    printf 'Cancellation is only safe before authorization/activation.\n' >&2
    exit 1
  fi
  # Publish cancellation before the worker can reach the activation gate.
  set_phase cancelled
  flock -u 9
  systemctl --user stop "$operationUnit" || true
  ;;
switch)
  selected="${2:-}"
  validate_theme "$selected"
  if [ "${USER:-}" != "$expectedUser" ]; then
    printf 'Theme chooser is configured for user %s\n' "$expectedUser" >&2
    exit 1
  fi
  if [ "${3:-}" != "--scoped" ]; then
    # Serialize launch before a transient scope becomes visible.
    exec 8>"${XDG_RUNTIME_DIR:?}/linux-desktop-theme-switch.lock"
    if ! flock -n 8 || systemctl --user --quiet is-active "$operationUnit"; then
      printf 'A theme activation is already running.\n' >&2
      exit 1
    fi
    mkdir -p "$operationDir"
    chmod 700 "$operationDir"
    exec 9>"$operationDir/operation.lock"
    flock -x 9
    printf '%s\n' "$selected" >"$operationDir/target"
    : >"$operationDir/output.log"
    chmod 600 "$operationDir/output.log" "$operationDir/target"
    set_phase preparing
    flock -u 9
    if ! systemd-run --user --scope --quiet --collect --unit=linux-desktop-theme-apply --description="Apply desktop theme $selected" -- "$0" switch "$selected" --scoped; then
      flock -x 9
      if [ "$(cat "$operationDir/phase" 2>/dev/null || :)" != cancelled ]; then
        set_phase failed
      fi
      flock -u 9
      exit 1
    fi
    exit 0
  fi
  exec >>"$operationDir/output.log" 2>&1
  trap finish_operation EXIT
  exec 9>"$operationDir/operation.lock"
  flock -x 9
  if [ "$(cat "$operationDir/phase" 2>/dev/null || :)" = cancelled ]; then
    flock -u 9
    exit 130
  fi
  set_phase building
  flock -u 9
  printf 'Building %s...\n' "$selected"
  nh os build "$themeFlakeRef" --hostname "$configurationName-$selected" --diff never
  flock -x 9
  if [ "$(cat "$operationDir/phase" 2>/dev/null || :)" = cancelled ]; then
    flock -u 9
    exit 130
  fi
  # The activation boundary is protected by the same lock as cancellation.
  set_phase authorizing
  flock -u 9
  printf 'Requesting permission to activate %s...\n' "$selected"
  set_phase activating
  nh os switch "$themeFlakeRef" --hostname "$configurationName-$selected" --diff never
  printf 'Activated %s.\n' "$selected"
  ;;
*)
  printf 'Usage: theme-set {list [--json]|current|switch <theme>|status|logs|cancel}\n' >&2
  exit 2
  ;;
esac
