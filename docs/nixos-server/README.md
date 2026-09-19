# NixOS Server Guide

Raspberry Pi home server documentation.

## Files

- `flake.nix`: declares the `nixos-server` host target.
- `docs/nixos-server/nixos-server-install.md`: end-to-end install, restore,
  and day-two operations guide.
- `docs/nixos-server/doppler-secrets.md`: scoped runtime-secret provisioning,
  migration, and recovery.
- `profiles/nixos-server/configuration_nixos-server.nix`: host networking,
  users, SSH, caches, and host-level services.
- `profiles/nixos-server/hosted-stack.nix`: hosted applications and their
  supporting runtime wiring, including app containers, backups,
  Snapper, and the AdGuard macvlan network.
- `profiles/nixos-server/hardware-configuration.nix`: this server's disk and
  filesystem layout.
- `profiles/nixos-server/image.nix`: the Raspberry Pi SD card image
  definition with the `FIRMWARE` boot partition, a 12 GiB seed image, and a
  Btrfs root layout that grows to the full card on first boot.
- [`docs/infrastructure-docs/docs/NETWORKING.md`](../infrastructure-docs/docs/NETWORKING.md): source-of-truth networking notes from the external infrastructure docs repo.

## Hardware Sources

`nixos-hardware.nixosModules.raspberry-pi-4` and
`profiles/nixos-server/hardware-configuration.nix` serve different purposes:

- `nixos-hardware.nixosModules.raspberry-pi-4`: Raspberry Pi 4 defaults shared
  by many machines, such as board-specific firmware and platform behavior.
- `profiles/nixos-server/hardware-configuration.nix`: this server's own disk
  labels, Btrfs subvolumes, boot layout, and kernel choice.

The split keeps board defaults separate from machine-specific storage
assumptions.

## Network Layout

- Router: `192.168.1.1`
- AdGuard: `192.168.1.2`
- NixOS host and Home Assistant: `192.168.1.3`
- AdGuard host shim: `192.168.1.5`
- DHCP pool: `192.168.1.100-192.168.1.199`

Home Assistant uses host networking, so it is reached at
`http://192.168.1.3:8123`.

The machine hostname is `nixos-server`, and the flake target is also
`nixos-server`.

AdGuard has its own macvlan IP because DNS clients should not care which host
it runs on.

## AdGuard Shim

Docker macvlan networks isolate the parent host from the container. The second
macvlan address on the host lets the Pi itself and host-networked Home
Assistant reach AdGuard. The macvlan parent interface is detected at runtime
from the default IPv4 route, so the config does not depend on whether the Pi
Ethernet interface is named `end0`, `eth0`, or something else.

That is why `hosted-stack.nix` creates:

- container IP `192.168.1.2` for AdGuard itself
- host shim IP `192.168.1.5` on `adguard-shim`
- a `/32` route for `192.168.1.2` through that shim

If more macvlan services are added later, widen the route or add more `/32`
routes.

## Tailscale Model

The server joins Tailscale as an ephemeral tagged subnet router:

```text
tag:nixos-server
```

It advertises `192.168.1.0/24`. Tailnet policy should auto-approve that route
for `tag:nixos-server`. The Tailscale `100.x` address is disposable; use LAN
URLs such as `http://192.168.1.3:8123` through the subnet route for stable access.

## Install

1. Build the `nixos-server` SD image from this repo on an `aarch64-linux`
   machine.
2. Flash the resulting image to the microSD card.
3. Boot the Pi, SSH in, and immediately change the temporary first-boot password.
4. Copy or clone this repo to `/home/joshan/.files`, keeping Git metadata so
   later `git pull` updates work on the server.
   Use `git clone --recurse-submodules` or run `git submodule update --init --recursive`
   after copying/cloning so `docs/infrastructure-docs` is present.
5. Create `/root/secrets` files:
   - `restic-password`
   - `rclone.conf`
   - `tailscale-oauth-client-id`
   - `tailscale-oauth-client-secret`
   - `n8n.env`
   - `openclaw.env`
6. Restore app data into `/var/lib/...` using the mapping below.
7. Apply the system:

```sh
sudo nixos-rebuild switch --flake /home/joshan/.files#nixos-server
```

## Restore Map

From the extracted Home Assistant backup:

- `homeassistant/data/` -> `/var/lib/home-assistant/`
- `a0d7b954_adguard/data/adguard/` -> `/var/lib/adguard/conf/`
- `core_matter_server/data/` -> `/var/lib/matter-server/`
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
sudo systemctl stop docker-home-assistant.service docker-adguard.service docker-matter-server.service docker-n8n.service docker-openclaw.service 2>/dev/null || true
sudo rsync -a /path/to/extracted/homeassistant/data/ /var/lib/home-assistant/
sudo rsync -a /path/to/extracted/a0d7b954_adguard/data/adguard/ /var/lib/adguard/conf/
sudo rsync -a /path/to/extracted/core_matter_server/data/ /var/lib/matter-server/
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
   app resolves each configured `repository:tag`, verifies a `linux/arm64` image
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

- Fast local rollback: Snapper snapshots `/var/lib` every 15 minutes.
- Offsite backup: restic sends `/var/lib/...` app data to Dropbox every 30
  minutes.
- Bootstrap secrets in `/root/secrets` are not part of that restic backup and
  should live in a password manager or separate encrypted archive.

## VM Variant

`virtualisation.vmVariant` lets `nixos-rebuild build-vm --flake .#nixos-server`
produce a test VM from the same host definition.

Shared VM sizing and build aliases live under `virtualisation.vm`; the server-specific safety overrides are nested under `virtualisation.vm.safety` because the real Pi assumptions do not fit a VM:

- Snapper and restic are disabled because the VM is just for build/testing and
  should not try to snapshot or back up fake data.
- The AdGuard macvlan unit is disabled because a QEMU VM does not have the
  real LAN interface used by the Pi deployment.
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
