#!/usr/bin/env bash
set -euo pipefail

update=${1:-$(git rev-parse --show-toplevel)/scripts/update-schemas.sh}
work=$(mktemp -d)
work=$(cd "$work" && pwd -P)
trap 'rm -rf "$work"' EXIT
export TMPDIR="$work/tmp"
export SCHEMA_TEST="$work"
mkdir -p "$TMPDIR" "$work/bin" "$work/repo with spaces/lib/schemas" "$work/output"
git init -q --bare "$work/remote.git"
cd "$work/repo with spaces"
git init -q
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid
git commit -qm initial --allow-empty
git remote add origin "$work/remote.git"
git push -q origin HEAD:refs/heads/schema-artifacts

cat >lib/schemas/registry.json <<'JSON'
{"example":{"input":"example","generator":"lib/schemas/generator.nix","generatorSources":["lib/schemas/generator.nix"]}}
JSON
printf '%s\n' '{ }' >lib/schemas/generator.nix
printf '%s\n' '{"root":"root","nodes":{"root":{"inputs":{"example":"example_2"}},"example_2":{"locked":{"rev":"0123456789012345678901234567890123456789"}}}}' >flake.lock
printf '%s\n' '{"type":"object"}' >"$work/output/schema.json"
export PATH="$work/bin:$PATH"
printf '#!%s\n' "$(command -v bash)" >"$work/bin/nix"
cat >>"$work/bin/nix" <<'STUB'
set -euo pipefail
case "$*" in
'eval --no-update-lock-file --raw --impure --expr '*)
  [[ $SCHEMA_INPUT == example ]]
  jq -r '.nodes[.nodes[.root].inputs.example].locked.rev' flake.lock
  ;;
'hash file --type sha256 --base16 '*) sha256sum "$6" | cut -d ' ' -f1 ;;
'eval --raw --impure --expr builtins.currentSystem') echo test-system ;;
'build --no-update-lock-file --no-link --print-out-paths --impure --expr '*)
  [[ $PWD == "$SCHEMA_TEST/repo with spaces" ]]
  [[ $SCHEMA_GENERATOR == lib/schemas/generator.nix && $SCHEMA_SYSTEM == test-system ]]
  [[ ${MODE:-} != build-failure ]] || exit 28
  printf '%s\n' "$SCHEMA_TEST/output"
  ;;
'flake update schema-artifacts') echo updated >>"$SCHEMA_TEST/updates" ;;
*) echo "Unexpected Nix invocation: $*" >&2; exit 99 ;;
esac
STUB
chmod +x "$work/bin/nix"

original=$(git ls-remote origin refs/heads/schema-artifacts | cut -f1)
for MODE in malformed missing-source build-failure; do
  export MODE
  cp lib/schemas/registry.json "$work/registry.json"
  case "$MODE" in
  malformed) printf '%s' '{' >lib/schemas/registry.json ;;
  missing-source) mv lib/schemas/generator.nix "$work/generator.nix" ;;
  esac
  if bash "$update"; then
    echo "Unexpected success: $MODE" >&2
    exit 1
  fi
  mv "$work/registry.json" lib/schemas/registry.json
  if [[ $MODE == missing-source ]]; then
    mv "$work/generator.nix" lib/schemas/generator.nix
  fi
  [[ $(git ls-remote origin refs/heads/schema-artifacts | cut -f1) == "$original" ]]
  [[ ! -e $work/updates ]]
  [[ -z $(ls -A "$TMPDIR") ]]
done
unset MODE
bash "$update"
git fetch -q origin schema-artifacts
[[ $(git show origin/schema-artifacts:example/source-revision) == 0123456789012345678901234567890123456789 ]]
[[ $(git show origin/schema-artifacts:example/generator-hash) == "$(sha256sum lib/schemas/generator.nix | cut -d ' ' -f1)" ]]
[[ $(git show origin/schema-artifacts:example/schema.json) == '{"type":"object"}' ]]
[[ $(cat "$work/updates") == updated ]]
[[ -z $(ls -A "$TMPDIR") ]]
# An unchanged source and generator must not regenerate or publish artifacts.
export MODE=build-failure
before=$(git rev-parse origin/schema-artifacts)
bash "$update"
[[ $(git rev-parse origin/schema-artifacts) == "$before" ]]
[[ $(wc -l <"$work/updates" | tr -d ' ') == 2 ]]
[[ -z $(ls -A "$TMPDIR") ]]
printf '%s\n' 'Schema refresh tests passed.'
