# Nix Binary Cache

The fleet uses a self-hosted Attic binary cache on the NixOS server. Cache data
is stored on the ZFS Vault, independently from every machine's `/nix/store`.
Running `nix-collect-garbage`, including `sudo nix-collect-garbage -d`, therefore
does not delete the persistent cache.

## Storage and retention

Attic stores its SQLite database and binary data under a dedicated ZFS dataset:

```text
vault/data       /srv/vault
vault/nix-cache  /srv/vault/nix-cache

/srv/vault/nix-cache/
├── server.db
└── storage/
```

The cache dataset is deliberately a sibling of `vault/data`, not a child of it.
Sanoid snapshots `vault/data` recursively, so cache churn is not retained in the
48-hour/14-day/8-week/12-month Vault snapshot history. This lets future Attic GC
actually reclaim cache space instead of leaving deleted chunks pinned by ZFS
snapshots.

`attic-cache-storage.service` verifies that `vault/nix-cache` exists and that
`/srv/vault/nix-cache` is a real mount point. `atticd.service` has the same mount
assertion. A missing or incorrectly mounted cache dataset therefore fails closed
rather than creating cache data on the SD-card root filesystem.

Attic time-based garbage collection starts disabled. Ordinary Nix GC and Attic
GC are deliberately separate controls. Retention can be enabled later after
real cache growth has been measured.

The cache is disposable acceleration data rather than primary data. The mirrored
Vault protects it from a single-disk failure, but the cache dataset is
intentionally outside Sanoid snapshots and the offsite restic backup.

## Upstream filtering

The `dotfiles` cache skips paths signed by every upstream binary cache currently
trusted by the NixOS fleet:

```text
cache.nixos.org-1
nix-community.cachix.org-1
nixos-raspberrypi.cachix.org-1
```

The GitHub Actions builder uses those same substituters and public keys. This is
important: when CI obtains a path from an upstream cache, its upstream signature
is present in the local Nix store and Attic can exclude it while pushing the
closure. Do not use `attic push --ignore-upstream-cache-filter` for normal CI
publishing.

This keeps the Vault focused on paths that actually had to be built for this
configuration instead of re-hosting binaries already available from an existing
trusted cache.

## Network boundary

Attic listens on TCP port 8080. The NixOS firewall permits that port only on the
server LAN interface and `tailscale0`.

Pull access should be public at the Attic cache level because the network itself
is private and Nix clients still verify signed narinfo metadata. Push access is
restricted to scoped Attic tokens.

## One-time server bootstrap

Create the sibling cache dataset before switching to the Attic-enabled NixOS
configuration. Dataset creation is explicit; normal NixOS activation only
verifies and uses it.

```bash
findmnt /srv/vault
sudo zfs create -o mountpoint=/srv/vault/nix-cache vault/nix-cache
zfs list vault/nix-cache
findmnt /srv/vault/nix-cache
```

Create the Attic signing/token secret on `nixos-server` before enabling the
service:

```bash
sudo sh -c 'umask 077; printf "ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=\"%s\"\n" "$(nix run nixpkgs#openssl -- genrsa -traditional 4096 | base64 -w0)" > /root/secrets/attic.env'
```

Build and switch the server configuration, then verify that the dataset guard is
working:

```bash
findmnt /srv/vault/nix-cache
sudo systemctl status attic-cache-storage.service atticd.service --no-pager
curl http://127.0.0.1:8080/
```

Generate a temporary administration token:

```bash
sudo atticd-atticadm make-token \
  --sub bootstrap \
  --validity '1 day' \
  --pull '*' \
  --push '*' \
  --create-cache '*' \
  --configure-cache '*' \
  --configure-cache-retention '*' \
  --destroy-cache '*'
```

Use that token locally to log in and create the fleet cache with all current
upstream signing keys:

```bash
attic login local http://127.0.0.1:8080 BOOTSTRAP_TOKEN
attic cache create local:dotfiles \
  --public \
  --upstream-cache-key-name cache.nixos.org-1 \
  --upstream-cache-key-name nix-community.cachix.org-1 \
  --upstream-cache-key-name nixos-raspberrypi.cachix.org-1
attic cache info local:dotfiles
```

`attic cache info` should report all three names under `Upstream Cache Keys`.
Keep this list aligned with the trusted upstream caches used by CI and the fleet.

Create a CI token scoped only to the fleet cache:

```bash
sudo atticd-atticadm make-token \
  --sub github-actions \
  --validity '1 year' \
  --pull dotfiles \
  --push dotfiles
```

Store that token in the GitHub repository secret `ATTIC_TOKEN`.

## GitHub Actions connection

`.github/workflows/system-upgrade-cache.yml` builds current host closures on
matching native GitHub runners:

| Nix system | Runner | Current profiles |
| --- | --- | --- |
| `x86_64-linux` | `ubuntu-24.04` | `nixos` |
| `aarch64-linux` | `ubuntu-24.04-arm` | `nixos-arm-parallels`, `nixos-orbstack`, `nixos-server` |

Configure these repository values before cache publishing is expected:

- variable `ATTIC_ENDPOINT`: the Tailscale-reachable Attic API endpoint, for
  example `http://nixos-server:8080` when Tailnet DNS resolves that hostname;
- secret `ATTIC_TOKEN`: the scoped `dotfiles` pull/push token;
- secret `TS_OAUTH_CLIENT_ID`: Tailscale OAuth client ID with writable
  `auth_keys` scope and permission to issue `tag:ci` nodes;
- secret `TS_OAUTH_SECRET`: matching Tailscale OAuth secret.

The workflow still performs builds when those values are absent, but skips the
publish phase with a notice. The Tailscale runner is ephemeral and joins only
for publishing.

## Flake update integration

`scripts/flake-update` already uses `system-upgrade` as its default update
branch. The cache workflow watches `system-upgrade*`, `upgrade-validation*`,
relevant pull requests, and `main`.

The normal update path is therefore:

```text
scripts/flake-update
        |
        v
system-upgrade* branch
        |
        | push / open PR
        v
native GitHub build matrix
        |
        v
attic push ci:dotfiles
        |
        +-- paths signed by a configured upstream cache --> skipped
        |
        `-- locally-built paths --> /srv/vault/nix-cache
```

The updater does not auto-push, auto-merge, or auto-deploy. CI population occurs
when the update branch is pushed for review.

## Architecture model

Attic storage is architecture-agnostic. Linux and Darwin store paths for any Nix
system can share the same `dotfiles` cache.

Use native builders first. Current GitHub-hosted runners cover the four primary
platform families expected by this repository:

- `x86_64-linux`;
- `aarch64-linux`;
- `x86_64-darwin`;
- `aarch64-darwin`.

When a future flake output targets a Linux architecture without a native hosted
runner, extend the build matrix with QEMU/binfmt emulation for that system. Keep
cross compilation as an explicit package-specific fallback rather than changing
the cache model. Darwin outputs still require Darwin builders; QEMU on Linux is
not a replacement for macOS.

Do not build every architecture speculatively. Add a builder lane when the flake
actually exposes an output for that system. This keeps CI and Vault usage tied
to real fleet requirements while preserving an architecture-independent cache.

## Client setup

After creating `dotfiles`, run:

```bash
attic cache info local:dotfiles
```

Record the public key reported by Attic. Client configuration should then add:

```text
http://nixos-server:8080/dotfiles
```

as a substituter and the reported `dotfiles:...` key as a trusted public key.
The public key is not secret and can be committed declaratively after bootstrap.
Keep the existing upstream caches configured as well; Attic intentionally does
not duplicate their paths.
