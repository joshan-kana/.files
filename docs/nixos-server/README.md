# NixOS Server Guide

Dell OptiPlex 7010 SFF home server documentation.

## Files

- `flake.nix`: declares the `nixos-server` x86_64 host target.
- `hosts/nixos-server/default.nix`: server host policy and composition.
- `hosts/nixos-server/hardware.nix`: OptiPlex hardware, boot, and label-based filesystem configuration.
- `hosts/nixos-server/options.nix`: server-only configuration inputs.
- `hosts/nixos-server/container-images.lock`: immutable OCI image locks.
- `docs/nixos-server/nixos-server-install.md`: bare-metal install and recovery procedure.
- [`docs/infrastructure-docs/docs/NETWORKING.md`](../infrastructure-docs/docs/NETWORKING.md): source-of-truth network plan.

## Hardware Configuration

The committed hardware configuration is based on `nixos-generate-config` output
from the OptiPlex. Generated kernel/initrd modules and Intel microcode settings
are retained, while filesystem mounts deliberately use stable labels instead of
partition UUIDs:

- `ROOT`: Btrfs root filesystem.
- `BOOT`: FAT32 EFI system partition mounted at `/boot`.

`/var/lib/apps` is a Btrfs subvolume on the root filesystem so the existing
Snapper configuration continues to snapshot application state independently.
The external `vault` ZFS pool remains separate and is imported without
recreating or formatting either member disk.

## Network Layout

- Router/default gateway: `192.168.1.1`
- AdGuard Home client DNS/filter: `192.168.1.2:53`
- NixOS host: `192.168.1.3`
- Technitium remote DNS/admin UI: `192.168.1.3:53` / `:5380`
- Technitium local backend endpoint: `127.0.0.1:5300`
- Current router DHCP pool: `192.168.1.100-192.168.1.199`

Home Assistant uses host networking, so it is reached at
`http://192.168.1.3:8123`.

The machine hostname is `nixos-server`, and the flake target is also
`nixos-server`.

AdGuard remains the only client-facing DNS resolver. It owns the dedicated
`192.168.1.2` service address and keeps network-wide ad/tracker filtering in
front of normal client queries. AdGuard forwards allowed queries to Technitium
over the loopback-only
`127.0.0.1:5300` backend. This keeps AdGuard filtering in front of normal LAN
queries while reserving `192.168.1.3:53` for direct remote `.home` DNS over
Tailscale. Technitium's official Drop Requests app blocks direct requests from
ordinary `192.168.1.0/24` clients while allowing loopback and the
4via6-translated `192.168.1.3/32` source, so LAN clients cannot bypass AdGuard
filtering by querying the backend directly. AdGuard also keeps a public fallback
resolver so loss of the Technitium backend does not take ordinary internet DNS
down with it.

Technitium owns the DNS/DHCP backend role and keeps its application-managed
state under `/var/lib/apps/technitium`, which is already protected by the
server app-data Snapper/restic policy. The authoritative `home` zone, DHCP
leases, DNS Apps, and roaming records therefore remain runtime application
state rather than duplicated Nix data.

On a genuinely empty Technitium state, its upstream default is to request
wildcard port 53. AdGuard may already own part of that socket space, but
Technitium keeps its web service running even when the DNS bind is unavailable.
AdGuard's public fallback keeps ordinary DNS working while the Technitium DNS
endpoints are restored/configured to `127.0.0.1:5300` and `192.168.1.3:53`.
Normal recovery restores `/var/lib/apps` first, so the persisted endpoint and
zone state is reused instead of repeating first-run setup.

The official Technitium Failover App provides roaming aliases. `mac.home`
prefers the DHCP-managed `joshans-macbook-pro.home` name while it responds on
the LAN and falls back to the Tailscale MagicDNS machine name
`joshans-macbook-pro.tailba46a0.ts.net` when the Mac leaves home. The record
contains names, not fixed LAN or Tailscale addresses.

The official DNS64 App is scoped to the translated Tailscale query path and
embeds `192.168.1.0/24` into the site-1 4via6 `/96`. Home queries arrive via
AdGuard's loopback backend and keep normal LAN IPv4 answers; remote `.home`
queries go directly to Technitium over 4via6 and receive collision-proof IPv6
answers for LAN-only destinations.

Technitium's DHCP scope remains disabled until the router DHCP service is
deliberately cut over; never run both DHCP servers at once. The staged scope
uses AdGuard (`192.168.1.2`) as client DNS, the router (`192.168.1.1`) as the
default gateway, dynamic leases from the non-infrastructure portion of the
subnet, and DHCP option 121 for `100.64.0.0/10` via `192.168.1.3` so home
clients can reach roaming tailnet peers without running Tailscale themselves.

### DHCP Cutover

Keep the Technitium scope disabled while the router is serving DHCP. For the
cutover:

1. Disable DHCP on the router.
2. Enable the `Default` scope in the Technitium web console.
3. Renew one client lease and confirm it receives gateway `192.168.1.1`, DNS
   `192.168.1.2`, and the `100.64.0.0/10` route via `192.168.1.3`.
4. Confirm the renewed client's DHCP hostname resolves through AdGuard.
5. Renew the remaining clients once the canary client is healthy.

Rollback is the reverse: disable the Technitium scope first, re-enable router
DHCP, then renew the affected client lease.

## Tailscale Model

The server joins Tailscale as an ephemeral tagged subnet router:

```text
tag:nixos-server
```

It advertises the ordinary home subnet plus the site-1 4via6 mapping:

```text
192.168.1.0/24
fd7a:115c:a1e0:b1a:0:1:c0a8:100/120
```

The 4via6 route keeps home devices unambiguous when a remote network also uses
`192.168.1.0/24`. Mutable route advertisement is applied with `tailscale set`
after the delayed autoconnect step, preserving the existing rule that Tailscale
authentication must not block normal LAN boot.

The server's ephemeral Tailscale `100.x` address is not a stable service
identity. Use `.home` names for services and Tailscale machine names for roaming
Tailscale peers.

Tailnet DNS keeps AdGuard filtering active while clients are away. The global
resolver is AdGuard's site-1 4via6 address, while `home` uses a restricted
resolver that goes directly to Technitium for split-view/DNS64 handling:

```text
global -> fd7a:115c:a1e0:b1a:0:1:c0a8:102  # 192.168.1.2 (AdGuard)
home   -> fd7a:115c:a1e0:b1a:0:1:c0a8:103  # 192.168.1.3 (Technitium)
```

Enable Tailscale's global DNS override. VPN On Demand disconnects Tailscale on
the home Wi-Fi, so home clients still use the DHCP-provided `192.168.1.2`
resolver directly. Away from home, Tailscale becomes active and sends normal
DNS through AdGuard while the more-specific `home` route goes to Technitium.

The stable Tailscale API can set the global resolver with
`POST /api/v2/tailnet/-/dns/nameservers` using a `dns` array and update the
restricted resolver with `PATCH /api/v2/tailnet/-/dns/split-dns` using a
`home` mapping. The existing OAuth client needs DNS write scope first; its
current device-management scope does not grant DNS access. Keep the Override
DNS setting as an admin-console toggle: Tailscale's all-in-one DNS configuration
API can express `overrideLocalDNS`, but the maintained client still marks that
endpoint alpha.

## Install

Use [NixOS Server Install Guide](nixos-server-install.md) for bare-metal install
and full-system recovery.

## Restore Map

From the extracted Home Assistant backup:

- `homeassistant/data/` -> `/var/lib/home-assistant/`
- `a0d7b954_adguard/data/adguard/` -> `/var/lib/adguard/conf/`
- `core_matter_server/data/` -> `/var/lib/apps/matter-server/`
- `3cfc8f0f_hass-n8n/data/n8n/.n8n/` -> `/var/lib/n8n/`

Special cases:

- AdGuard `work/` data is not present in the HA backup. Let the NixOS
  container recreate `/var/lib/adguard/work`.
- OpenClaw old state is not migrated by default. Start fresh in
  `/var/lib/openclaw` and `/var/lib/openclaw-auth` unless you later choose to
  restore pieces of `17e0cc66_openclaw_assistant/`.
- Twingate is not restored. Tailscale replaces it. The server joins as an
  ephemeral tagged subnet router, advertises the LAN route, and uses the
  OAuth client credentials in `/root/secrets/tailscale-oauth-client-id` and
  `/root/secrets/tailscale-oauth-client-secret`.
- Home Assistant's `secrets.yaml` is restored as part of
  `/var/lib/home-assistant/`.

Restore flow:

```sh
sudo systemctl stop home-assistant.service docker-adguard.service docker-matter-server.service matter-server.service docker-n8n.service docker-openclaw.service 2>/dev/null || true
sudo rsync -a /path/to/extracted/homeassistant/data/ /var/lib/home-assistant/
sudo rsync -a /path/to/extracted/a0d7b954_adguard/data/adguard/ /var/lib/adguard/conf/
sudo rsync -a /path/to/extracted/core_matter_server/data/ /var/lib/apps/matter-server/
sudo rsync -a /path/to/extracted/3cfc8f0f_hass-n8n/data/n8n/.n8n/ /var/lib/n8n/
sudo nixos-rebuild switch --flake /home/joshan/.files#nixos-server
```

## Updates

There are three update paths:

1. Mutable app config updates:
   Edit the live files under `/var/lib/...`, such as Home Assistant YAML,
   AdGuard config, or the n8n database.

2. NixOS and native service updates:
   Update the flake inputs, commit the lock file, then rebuild:

```sh
nix flake update
git add flake.lock
git commit -m "chore: update flake inputs"
sudo nixos-rebuild switch --flake /home/joshan/.files#nixos-server
```

This updates NixOS itself plus native services such as Tailscale. The exact
revision of Nixpkgs (and hence the native service versions) is controlled by
`flake.lock`. Container image digests are handled separately (path 3) so
unrelated flake input changes do not restart the hosted containers.

3. Hosted container image updates:
   The server containers are pinned to immutable digests recorded in
   `hosts/nixos-server/container-images.lock`. The `update-container-lock` flake
   app resolves each configured `repository:tag`, verifies an image for the target host platform
   is available, and rewrites the lock atomically.

```sh
nix run .#update-container-lock -- [<configuration>/<container>...]
```

The `system-upgrade` app opens a multi-select picker for flake inputs and
containers, then validates the result. Automation can explicitly update everything:

```sh
nix run .#system-upgrade
nix run .#system-upgrade -- --all
```

A full container refresh rebuilds the lock from the currently configured registry
containers; a selected refresh preserves unselected lock entries.

## OCI Container Model

The server uses the NixOS `virtualisation.oci-containers` module with the Docker
backend. Nix declares the container service boundary, volumes, environment
files, networking, and systemd ordering. The application data remains in
`/var/lib/...` so it can be snapshotted, backed up, and restored separately from
the container image.

Containers are declared with normal NixOS OCI-container syntax. Each keeps an
`image = "repository:tag";` source plus its volumes, ports, environment files,
and extra options in the relevant `modules/server-apps/<app>/` module:

```nix
virtualisation.oci-containers.containers.openclaw = {
  image = "ghcr.io/openclaw/openclaw:latest";
  environmentFiles = [ "${secretsDir}/openclaw.env" ];
  volumes = [ "${appDataRoot}/openclaw:/home/node/.openclaw" ];
};
```

`modules/virtualisation/containers/image-locking.nix` adds an `apply` transformation to the
upstream `virtualisation.oci-containers.containers` option for the server. After every
container definition across the whole module graph has merged, it appends the
matching locked digest from `container-images.lock`, producing
`repository:tag@sha256:<digest>` at evaluation time. The transformation is
global and does not depend on where an app module lives in the server module
graph.

The lock is keyed by container name. Two containers may intentionally follow the
same `repository:tag` source and still have independent lock records and
targeted-update behavior.

Image locking is the `virtualisation.containers.imageLocking` semantic child. It is enabled by
default with the server container stack and can be bypassed without disabling
Docker/OCI containers:

```nix
dotfiles.scopes.virtualisation.containers.imageLocking.enable = false;
```

Disabling `dotfiles.scopes.virtualisation.containers.enable` disables the shared Docker/OCI
runtime as well and also bypasses locking.

If a container's lock entry is missing, stale, or malformed, the module writes a
placeholder digest (`sha256:0000…`) into the image. That lets the updater
discover the new source, but a NixOS assertion prevents building or deploying
the system until the lock is refreshed:

```sh
nix run .#update-container-lock
```

The updater evaluates the final merged OCI-container option after any flake
update, then resolves the requested registry digests with Skopeo. Locally built
or streamed images (`imageFile` / `imageStream`) are left unchanged and need no
lock entry.

This is reproducible: the exact container image digest is data stored in
`container-images.lock`, which is reviewed and committed like `flake.lock`. For
even stricter rollback, selected images could move to `imageFile` or
`imageStream` so they are loaded from the Nix store instead of pulled directly
by Docker.

Deployment remains a separate, reviewed step. Before a live `switch`, run
`sudo nixos-rebuild dry-activate --flake .#nixos-server` to confirm which units
would restart: a digest change should restart only the affected container
service, an unrelated `flake.lock` change should not restart every container,
and unchanged container definitions should not restart. Do not assume container
image rollback is universally safe: applications such as Home Assistant, n8n,
or Plane may run database migrations on upgrade, and restoring the previous
image digest does not necessarily undo a completed migration.

## Rollback And Backup

- Fast local rollback: Snapper protects application data according to the configured storage policy.
- App-data offsite backup: Restic protects the server's persistent application data.
- Secret offsite backup: Restic protects server runtime secrets, primary-user secrets, and account state in a dedicated encrypted repository.
- The external recovery store holds only the break-glass bootstrap material required to reach and decrypt the backups.

## VM Variant

`virtualisation.vmVariant` lets `nixos-rebuild build-vm --flake .#nixos-server`
produce a test VM from the same host definition.

Shared VM sizing and build aliases live under `virtualisation.vm`; the
server-specific safety overrides are nested under `virtualisation.vm.safety`:

- Snapper and restic are disabled because the VM is just for build/testing and
  should not try to snapshot or back up fake data.
- The AdGuard macvlan unit is disabled because a QEMU VM does not have the
  server's physical LAN interface.
- AdGuard falls back from a dedicated macvlan IP to normal published ports so
  the service can still start inside the VM.

Without those overrides, the VM build would inherit real-hardware networking
assumptions and fail.

## Reference Data

Do not keep extracted Home Assistant backups in Git, even sanitized ones. Use:

- Dropbox or another encrypted backup target for the real archives
- a local directory outside the repo when you need to inspect a backup beside
  the working tree

Keep raw archives, extracted contents, and any secret-bearing inspection copies
out of the repository.
