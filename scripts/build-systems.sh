#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

nixos="$(nix eval --json .#nixosConfigurations --apply builtins.attrNames)"
darwin="$(nix eval --json .#darwinConfigurations --apply builtins.attrNames)"

targets=()
while IFS= read -r host; do
  targets+=(".#nixosConfigurations.$host.config.system.build.toplevel")
done < <(jq -r '.[]' <<<"$nixos")
while IFS= read -r host; do
  targets+=(".#darwinConfigurations.$host.system")
done < <(jq -r '.[]' <<<"$darwin")

if ((${#targets[@]} == 0)); then
  echo 'No system configurations found' >&2
  exit 1
fi

exec rom build "${targets[@]}" -- -L --no-link "$@"
