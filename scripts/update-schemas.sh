#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"
registry=lib/schemas/registry.json

if [[ ${1:-} == --list ]]; then
  jq -r 'keys[]' "$registry"
  exit 0
fi

if [[ $# == 0 || ($# == 1 && $1 == --all) ]]; then
  names=$(jq -r 'keys[]' "$registry")
  [[ -n $names ]] || exit 0
  mapfile -t selected <<<"$names"
else
  selected=("$@")
fi

for name in "${selected[@]}"; do
  if ! jq -e --arg name "$name" 'has($name)' "$registry" >/dev/null; then
    printf 'Unknown generated schema: %s\n' "$name" >&2
    exit 2
  fi
done

git fetch --quiet origin schema-artifacts

tmp="$(mktemp -d "${TMPDIR:-/tmp}/schema-update.XXXXXXXX")"
cleanup() {
  git worktree remove --force "$tmp" >/dev/null 2>&1 || rm -rf "$tmp"
}
trap cleanup EXIT

git worktree add --detach --quiet "$tmp" origin/schema-artifacts
changed=false
for name in "${selected[@]}"; do
  input="$(jq -er --arg name "$name" '.[$name].input | strings | select(length > 0)' "$registry")"
  generator="$(jq -er --arg name "$name" '.[$name].generator | strings | select(length > 0)' "$registry")"
  # shellcheck disable=SC2016 # The expression is evaluated by Nix.
  revision="$(SCHEMA_INPUT="$input" nix eval --no-update-lock-file --raw --impure --expr '
    let flake = builtins.getFlake (toString ./.);
    in flake.inputs.${builtins.getEnv "SCHEMA_INPUT"}.rev
  ')"
  [[ $revision =~ ^[0-9a-f]{40}$ ]] || {
    echo "No locked revision for $name ($input)" >&2
    exit 1
  }

  sources="$(jq -er --arg name "$name" '.[$name].generatorSources | if type == "array" and length > 0 and all(.[]; type == "string" and length > 0) then .[] else error("Invalid generator sources") end' "$registry")"
  hashFile="$tmp/.generator-hash-input"
  : >"$hashFile"
  while IFS= read -r filename; do
    [[ -f $filename ]] || {
      echo "Missing generator source: $filename" >&2
      exit 1
    }
    cat "$filename" >>"$hashFile"
  done <<<"$sources"
  generator_hash="$(nix hash file --type sha256 --base16 "$hashFile")"
  rm -f "$hashFile"

  current_revision="$(cat "$tmp/$name/source-revision" 2>/dev/null || true)"
  current_hash="$(cat "$tmp/$name/generator-hash" 2>/dev/null || true)"
  if [[ $revision == "$current_revision" && $generator_hash == "$current_hash" ]]; then
    continue
  fi

  system="$(nix eval --raw --impure --expr builtins.currentSystem)"
  output="$(SCHEMA_GENERATOR="$generator" SCHEMA_SYSTEM="$system" nix build --no-update-lock-file --no-link --print-out-paths --impure --expr '
    let flake = builtins.getFlake (toString ./.);
    in import (./. + ("/" + builtins.getEnv "SCHEMA_GENERATOR")) {
      inputs = flake.inputs;
      system = builtins.getEnv "SCHEMA_SYSTEM";
    }
  ')"
  [[ -s "$output/schema.json" ]] || {
    echo "No generated schema for $name" >&2
    exit 1
  }
  jq -e . "$output/schema.json" >/dev/null
  mkdir -p "$tmp/$name"
  cp "$output/schema.json" "$tmp/$name/schema.json"
  printf '%s\n' "$revision" >"$tmp/$name/source-revision"
  printf '%s\n' "$generator_hash" >"$tmp/$name/generator-hash"
  changed=true
done

if [[ $changed == true ]]; then
  git -C "$tmp" add --all
  if ! git -C "$tmp" diff --cached --quiet; then
    git -C "$tmp" commit -qm 'Update generated schemas'
    git -C "$tmp" push --quiet origin HEAD:refs/heads/schema-artifacts
  fi
fi
nix flake update schema-artifacts
