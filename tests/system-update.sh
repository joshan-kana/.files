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
'eval --json .#lib.updateablePackages')
  [[ $MODE != package-discovery ]] || exit 23
  printf '%s' '{"test-system":["package"]}'
  ;;
'flake metadata --json --no-update-lock-file')
  [[ $MODE != input-discovery ]] || exit 24
  printf '%s' '{"locks":{"root":"root","nodes":{"root":{"inputs":{"example":"example"}}}}}'
  ;;
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
for command in update-container-lock update-schemas fzf; do
  printf '#!%s\n' "$(command -v bash)" >"$work/bin/$command"
done
cat >>"$work/bin/update-container-lock" <<'STUB'
if [[ ${1:-} == --list ]]; then
  [[ $MODE != container-discovery ]] || exit 25
  echo host/container
else
  echo update-container-lock >>"$CALLS"
fi
STUB
cat >>"$work/bin/update-schemas" <<'STUB'
if [[ ${1:-} == --list ]]; then
  [[ $MODE != schema-discovery ]] || exit 26
  echo schema
else
  echo update-schemas >>"$CALLS"
fi
STUB
cat >>"$work/bin/fzf" <<'STUB'
echo picker >>"$CALLS"
cat >"$CALLS.choices"
case "$MODE" in
cancel) exit 130 ;;
no-selection) exit 1 ;;
picker-error) exit 2 ;;
*) exit 99 ;;
esac
STUB
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

for MODE in package-discovery input-discovery container-discovery schema-discovery cancel no-selection picker-error; do
  export MODE
  : >"$CALLS"
  status=0
  bash "$update" || status=$?
  case "$MODE" in
  package-discovery) [[ $status == 23 ]] ;;
  input-discovery) [[ $status == 24 ]] ;;
  container-discovery) [[ $status == 25 ]] ;;
  schema-discovery) [[ $status == 26 ]] ;;
  cancel | no-selection) [[ $status == 0 ]] ;;
  picker-error) [[ $status == 2 ]] ;;
  esac
  case "$MODE" in
  *-discovery) [[ ! -s $CALLS ]] ;;
  *)
    [[ $(cat "$CALLS") == picker ]]
    grep -Fxq $'package\ttest-system/package' "$CALLS.choices"
    grep -Fxq $'input\texample' "$CALLS.choices"
    grep -Fxq $'container\thost/container' "$CALLS.choices"
    grep -Fxq $'schema\tschema' "$CALLS.choices"
    ;;
  esac
done
printf '%s\n' 'Interactive update discovery tests passed.'
