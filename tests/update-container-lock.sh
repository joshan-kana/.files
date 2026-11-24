#!/usr/bin/env bash
set -euo pipefail

update=${1:-$(git rev-parse --show-toplevel)/scripts/update-container-lock.sh}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/repo"
cd "$work/repo"
git init -q
export PATH="$work/bin:$PATH"
export CONTAINER_TEST="$work"
export TMPDIR="$work/tmp"
mkdir -p "$TMPDIR"
for command in nix skopeo; do
  printf '#!%s\n' "$(command -v bash)" >"$work/bin/$command"
done
cat >>"$work/bin/nix" <<'STUB'
cat "$CONTAINER_TEST/inventory.json"
STUB
cat >>"$work/bin/skopeo" <<'STUB'
set -euo pipefail
case "$1 $2" in
'inspect --raw')
  [[ ${MODE:-} != registry-failure ]] || exit 23
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
unset MODE
bash "$update"
expected=$(printf 'sha256:%064d' 1)
for lock in first.json second.json; do
  jq -e --arg digest "$expected" '.app == {source:"example/app:latest",digest:$digest}' "$lock" >/dev/null
done
[[ -z $(ls -A "$TMPDIR") ]]
printf '%s\n' 'Container lock update tests passed.'
