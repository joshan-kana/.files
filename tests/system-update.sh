#!/usr/bin/env bash
set -euo pipefail

update=${1:-$(git rev-parse --show-toplevel)/scripts/system-update.sh}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/repo"
cd "$work/repo"
git init -q
export PATH="$work/bin:$PATH"
export CALLS="$work/calls"

printf '#!%s\n' "$(command -v bash)" >"$work/bin/nix"
cat >>"$work/bin/nix" <<'STUB'
set -euo pipefail
case "$*" in
'flake update') echo inputs >>"$CALLS" ;;
'eval --raw --impure --expr builtins.currentSystem') printf '%s' test-system ;;
'eval --json .#lib.routinePackageUpdates')
  case "$MODE" in
  failure) exit 23 ;;
  malformed) printf '%s' '{' ;;
  empty) printf '%s' '{}' ;;
  esac
  ;;
*) echo "Unexpected nix invocation: $*" >&2; exit 99 ;;
esac
STUB
for command in update-container-lock update-schemas; do
  # shellcheck disable=SC2016 # The stub expands CALLS when it runs.
  printf '#!%s\necho %s >>"$CALLS"\n' "$(command -v bash)" "$command" >"$work/bin/$command"
done
chmod +x "$work/bin/"*

for MODE in failure malformed empty; do
  export MODE
  : >"$CALLS"
  status=0
  bash "$update" --all || status=$?
  case "$MODE" in
  failure) [[ $status == 23 ]] ;;
  malformed) [[ $status != 0 ]] ;;
  empty) [[ $status == 0 ]] ;;
  esac
  expected=$'inputs\nupdate-container-lock'
  if [[ $MODE == empty ]]; then
    expected+=$'\nupdate-schemas'
  fi
  [[ $(cat "$CALLS") == "$expected" ]]
done
printf '%s\n' 'Routine update discovery tests passed.'
