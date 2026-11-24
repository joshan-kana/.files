#!/usr/bin/env bash
set -euo pipefail

update=${1:-$(git rev-parse --show-toplevel)/scripts/update-container-lock.sh}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/repo"
cd "$work/repo"
git init -q
REAL_JQ=$(command -v jq)
export REAL_JQ
export PATH="$work/bin:$PATH"
export CONTAINER_TEST="$work"
export TMPDIR="$work/tmp"
mkdir -p "$TMPDIR"
for command in nix jq skopeo; do
  printf '#!%s\n' "$(command -v bash)" >"$work/bin/$command"
done
cat >>"$work/bin/nix" <<'STUB'
cat "$CONTAINER_TEST/inventory.json"
STUB
cat >>"$work/bin/jq" <<'STUB'
set -euo pipefail
if [[ ${MODE:-} == slow-workers && ${2:-} == 'map(.source) | unique[]' ]]; then
  "$REAL_JQ" "$@"
  # Leave the inventory process alive after mapfile has read its output.
  exec 1>&-
  sleep 0.1
else
  exec "$REAL_JQ" "$@"
fi
STUB
cat >>"$work/bin/skopeo" <<'STUB'
set -euo pipefail
case "$1 $2" in
'inspect --raw')
  [[ ${MODE:-} != registry-failure ]] || exit 23
  if [[ ${MODE:-} == slow-workers ]]; then
    sleep 0.3
  fi
  if [[ ${MODE:-} == partial-failure && $3 == docker://example/extra-2:latest ]]; then
    exit 23
  fi
  printf '%s\n' '{"manifests":[{"platform":{"os":"linux","architecture":"amd64"}}]}'
  ;;
'manifest-digest '*) printf 'sha256:%064d\n' 1 ;;
*) exit 99 ;;
esac
STUB
chmod +x "$work/bin/"*
cat >"$work/inventory.json" <<'JSON'
{"first":{"lockFile":"first.json","platform":{"os":"linux","architecture":"amd64"},"containers":{"app":"example/app:latest"}},"second":{"lockFile":"second.json","platform":{"os":"linux","architecture":"amd64"},"containers":{"app":"example/app:latest"}}}
JSON
printf '%s\n' '{}' >first.json
for MODE in malformed wrong-type registry-failure; do
  export MODE
  case "$MODE" in
  malformed) printf '%s' '{' >second.json ;;
  wrong-type) printf '%s\n' '[]' >second.json ;;
  registry-failure) printf '%s\n' '{}' >second.json ;;
  esac
  cp second.json "$work/second.before"
  if bash "$update"; then
    echo "Unexpected success: $MODE" >&2
    exit 1
  fi
  [[ $(cat first.json) == '{}' ]]
  cmp second.json "$work/second.before"
  [[ -z $(ls -A "$TMPDIR") ]]
done
MODE=slow-workers bash "$update"
unset MODE
expected=$(printf 'sha256:%064d' 1)
for lock in first.json second.json; do
  jq -e --arg digest "$expected" '.app == {source:"example/app:latest",digest:$digest}' "$lock" >/dev/null
done
[[ -z $(ls -A "$TMPDIR") ]]
# Exercise more unique sources than the worker limit and a mixed outcome.
jq '.first.containers += (reduce range(1; 6) as $i ({}; .["extra-\($i)"] = "example/extra-\($i):latest"))' \
  "$work/inventory.json" >"$work/inventory.next"
mv "$work/inventory.next" "$work/inventory.json"
cp first.json "$work/first.before"
cp second.json "$work/second.before"
if MODE=partial-failure bash "$update"; then
  echo "Unexpected success: partial-failure" >&2
  exit 1
fi
cmp first.json "$work/first.before"
cmp second.json "$work/second.before"
[[ -z $(ls -A "$TMPDIR") ]]
MODE=slow-workers bash "$update"
jq -e --arg digest "$expected" 'length == 6 and all(.[]; .digest == $digest)' first.json >/dev/null
cmp second.json "$work/second.before"
[[ -z $(ls -A "$TMPDIR") ]]
printf '%s\n' 'Container lock update tests passed.'
