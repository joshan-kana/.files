#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
vendored="$repo_root/hosts/nixos-orbstack/generated.nix"
live="/etc/nixos/orbstack.nix"

tmp_files=()
cleanup() {
  rm -rf "${tmp_files[@]}"
}
trap cleanup EXIT

normalize() {
  local input="$1"
  local output="$2"
  local scratch_dir
  local scratch

  scratch_dir="$(mktemp -d "$repo_root/.orbstack-normalize.XXXXXX")"
  tmp_files+=("$scratch_dir")
  scratch="$scratch_dir/generated.nix"
  cp "$input" "$scratch"
  nix fmt "$scratch" >/dev/null
  cp "$scratch" "$output"
}

if [[ -r "$live" ]]; then
  live_file="$live"
elif command -v orb >/dev/null 2>&1; then
  tmp_file="$(mktemp)"
  tmp_files+=("$tmp_file")
  orb -m nixos cat "$live" > "$tmp_file"
  live_file="$tmp_file"
else
  echo "Cannot read $live and orb is not available." >&2
  exit 2
fi

vendored_normalized="$(mktemp)"
live_normalized="$(mktemp)"
tmp_files+=("$vendored_normalized" "$live_normalized")

normalize "$vendored" "$vendored_normalized"
normalize "$live_file" "$live_normalized"

diff -u \
  --label "vendored normalized: hosts/nixos-orbstack/generated.nix" \
  --label "live normalized: /etc/nixos/orbstack.nix" \
  "$vendored_normalized" \
  "$live_normalized"
