# Native OpenClaw Gateway

Status: investigation only. Keep the Docker OpenClaw service as the production path until the native package path is proven on `aarch64-linux`.

## Findings

OpenClaw has an upstream Nix flake at `openclaw/nix-openclaw` that packages the gateway and exports `nixosModules.openclaw-gateway`.

That flake is not currently a safe drop-in for the Raspberry Pi server because:

- its published `systems` list includes `x86_64-linux` and `aarch64-darwin`, but not `aarch64-linux`;
- its advertised binary cache is `https://cache.garnix.io`, which should not be relied on for new Pi deployments;
- building the whole Node/OpenClaw package graph locally on the Pi may be slow and brittle.

`numtide/llm-agents.nix` has the better cache story for this repo, but it does not currently package OpenClaw. Adding `https://cache.numtide.com` to this repo would not make a locally written OpenClaw derivation cached unless the same derivation is also built and published by that cache.

## Direction

Do not add `openclaw/nix-openclaw` to the server flake yet.

Do not port the gateway through `numtide/llm-agents.nix` until OpenClaw is packaged there, or until this repo has another maintained `aarch64-linux` binary cache for the OpenClaw derivation.

A native service should wait until one of these is true:

1. upstream `nix-openclaw` supports and caches `aarch64-linux`, preferably through a maintained cache such as Cachix or GitHub Actions-backed Nix cache;
2. `numtide/llm-agents.nix` packages OpenClaw and publishes `aarch64-linux` substitutes through `cache.numtide.com`;
3. this repo vendors a small OpenClaw package expression and publishes it to a maintained cache;
4. the server is moved from the Raspberry Pi to stronger hardware where local builds are acceptable.

## Future service shape

When packaging is ready, the native service should preserve the current runtime model:

- run the gateway on loopback port `18789`;
- keep nginx as the LAN-facing reverse proxy on `192.168.1.3:18789`;
- keep secrets under `/root/secrets`;
- store state under `/var/lib/apps/openclaw` or a clearly migrated native state directory;
- preserve the existing `openclaw-admin` loopback SSH host-access model only if it is still needed.
