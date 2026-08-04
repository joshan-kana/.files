# NixOS Server Guide

Raspberry Pi home server documentation.

## Files

- `flake.nix`: declares the `nixos-server` host target.
- `docs/nixos-server/nixos-server-install.md`: end-to-end install, restore,
  and day-two operations guide.
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
  OAuth client secret in `/root/secrets/tailscale-oauth-client-secret`.
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

2. NixOS and bare-metal service updates:
   Update the flake inputs, commit the lock file, then rebuild:

```sh
nix flake update
git add flake.lock
git commit -m "chore: update flake inputs"
sudo nixos-rebuild switch --flake /home/joshan/.files#nixos-server
```

This updates NixOS itself plus bare-metal services such as Tailscale. The exact
revision of Nixpkgs (and hence the native service versions) is controlled by
`flake.lock`. Container image digests are handled separately (path 3) so
unrelated flake input changes do not restart the hosted containers.

3. Hosted container image updates:
   The server containers are pinned to immutable digests recorded in the
   generated JSON file `hosts/nixos-server/container-images.lock`. Each
   container declares its upstream repository, tracked tag/channel, and full
   OCI configuration once in the mergeable `dotfiles.server.containerDefinitions`
   option (set in `hosts/nixos-server/apps.nix`, and available to future
   modules). `scripts/update-container-images` resolves each configured
   `repository:tag` to its current manifest index digest, proves a `linux/arm64`
   image is available, and rewrites the lock atomically. A container restarts
   only when its own locked digest (or its service definition) changes.

```sh
scripts/update-container-images
git add hosts/nixos-server/container-images.lock
git commit -m "chore(server): refresh container image digests"
sudo nixos-rebuild switch --flake /home/joshan/.files#nixos-server
```

`sysfu server` (the interactive `scripts/flake-update` wrapper) updates the flake
inputs and, for the server target, refreshes the container lock as part of the
same workflow. Container-specific options:

- `sysfu server` — full flake update and a full container lock refresh.
- `sysfu server --containers-only` — refresh only the container lock; skip the
  flake input update.
- `sysfu server --container <name>` — refresh only the named container(s);
  repeatable, and **skips the flake input update** unless flake inputs are also
  supplied. Unselected entries are preserved.
- `sysfu server --no-containers` — run the normal flake update but leave
  container images untouched.

A **full** container refresh rebuilds the lock exactly from the currently
configured sources: removed containers disappear and stale keys cannot survive.
A **selected** refresh (`--container <name>` / `CONTAINER_SELECT`) resolves only
the named containers and preserves every other lock entry unchanged. Container
options are rejected on non-server targets, and `--no-containers` cannot be
combined with `--containers-only` or `--container`. A selected flake-input update
(such as `sysfu server nixpkgs-stable`) refreshes the container lock only if a
container option is explicitly given, so a narrow flake update does not
unexpectedly move every container.

## OCI Container Model

The server uses the NixOS `virtualisation.oci-containers` module with the Docker
backend. Nix declares the container service boundary, volumes, environment
files, networking, and systemd ordering. The application data remains in
`/var/lib/...` so it can be snapshotted, backed up, and restored separately from
the container image.

Each container is declared once via the mergeable `dotfiles.server.containerDefinitions`
option in `hosts/nixos-server/apps.nix` with its upstream `repository`, tracked
`tag`, and full OCI `container` configuration. A central derivation turns the
merged definitions into both the runtime containers and the updater metadata, so
a container's source and configuration are declared exactly once. Future service
modules (for example `planning-hubs/plane.nix` or `huly.nix`) can register
additional containers by extending `dotfiles.server.containerDefinitions` without
duplicating the lock-reading or digest-locking logic. The generated
`container-images.lock` records the resolved `source` (repository:tag) and the
immutable index `digest` for each container.

`scripts/update-container-images-test` is a deterministic negative test that
feeds a synthetic amd64-only image index through a mocked resolver and confirms
the updater exits non-zero, reports the missing `linux/arm64` manifest, and
leaves the lock file unchanged.

The runtime image reference is `repository@sha256:<digest>` (the tracked tag is
update metadata for the updater, not part of the deployed reference) with a
`pull` policy of `missing`. The digest pins the exact image, so a registry
change or upstream tag mutation does not affect the running server until
`scripts/update-container-images` is run and the new digest is committed.

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

The overrides exist because the real Pi assumptions do not fit a VM:

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
