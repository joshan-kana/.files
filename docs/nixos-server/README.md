# NixOS Server Guide

Raspberry Pi home server documentation.

## Files

- `flake.nix`: declares the `nixos-server` host target.
- `docs/nixos-server/nixos-server-install.md`: end-to-end install, restore,
  and day-two operations guide.
- `profiles/nixos-server/configuration_nixos-server.nix`: host networking,
  users, SSH, caches, and host-level services.
- `profiles/nixos-server/hosted-stack.nix`: hosted applications and their
  supporting runtime wiring, including Home Assistant, AdGuard, Matter, n8n,
  OpenClaw, backups, Snapper, and the AdGuard macvlan network.
- `profiles/nixos-server/hardware-configuration.nix`: this server's disk and
  filesystem layout.
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
Assistant reach AdGuard.

That is why `hosted-stack.nix` creates:

- container IP `192.168.1.2` for AdGuard itself
- host shim IP `192.168.1.5` on `adguard-shim`
- a `/32` route for `192.168.1.2` through that shim

If more macvlan services are added later, widen the route or add more `/32`
routes.

## Install

1. Flash the official NixOS AArch64 SD image for Raspberry Pi.
2. Prepare the target disk with:
   - `FIRMWARE` as the FAT boot partition
   - `NIXOS` as the Btrfs partition
   - Btrfs subvolumes `root` and `var-lib`
3. Clone this repo to `/home/joshan/.files` on the Pi.
   Use `git clone --recurse-submodules` or run `git submodule update --init --recursive`
   after cloning so `docs/infrastructure-docs` is present.
4. Create `/root/secrets` files:
   - `restic-password`
   - `rclone.conf`
   - `tailscale-authkey`
   - `n8n.env`
   - `openclaw.env`
5. Restore app data into `/var/lib/...` using the mapping below.
6. Apply the system:

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
  `/var/lib/openclaw` unless you later choose to restore pieces of
  `17e0cc66_openclaw_assistant/`.
- Twingate is not restored. Tailscale replaces it, advertises the LAN route,
  and stores live state in `/var/lib/tailscale`.
- Home Assistant's `secrets.yaml` is restored as part of
  `/var/lib/home-assistant/`.

Restore flow:

```sh
sudo systemctl stop docker-home-assistant.service docker-adguard.service docker-matter-server.service n8n.service 2>/dev/null || true
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
   Edit the repo, update the submodule, commit the change, then run:

```sh
git submodule update --init --recursive
sudo nixos-rebuild switch --flake /home/joshan/.files#nixos-server
```

This updates NixOS itself plus bare-metal services such as Tailscale.

3. Hosted app version updates:
   Change the image tag or digest in `profiles/nixos-server/hosted-stack.nix`
   for containerized services, or update the server package set for native
   services such as `n8n`, then commit and rebuild.

Floating tags like `stable` and `latest` still exist in the stack. Pinned
versions or digests are better for reproducible rollbacks.

To move the server to a newer stable NixOS package set:

```sh
nix flake lock --update-input nixpkgs-stable --update-input nixos-hardware
git commit -am "Update server nixpkgs"
sudo nixos-rebuild switch --flake /home/joshan/.files#nixos-server
```

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
- The AdGuard macvlan unit is disabled because a QEMU VM does not have your
  real `end0` LAN interface.
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
