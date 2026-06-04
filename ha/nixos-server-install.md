# Installing NixOS On The Raspberry Pi 4

## Shape Of This Host

The flake has one server target:

- `nixos-server`: the real Raspberry Pi 4 target, built for `aarch64-linux`.

The target also has a NixOS VM variant, so test builds use the same name:

```sh
nixos-rebuild build-vm --flake .#nixos-server
```

The server target does not import `/etc/nixos/hardware-configuration.nix`. It
uses the Raspberry Pi 4 profile from `nixos-hardware`, while the local
hardware/filesystem assumptions are checked into
`profiles/nixos-server/hardware-configuration.nix`.

## Recommended Install Path

Use the official NixOS AArch64 SD image path for the Pi. The NixOS Raspberry Pi
4 wiki notes that the Pi 4 family is supported as AArch64, and the ARM docs
recommend SD card images for Raspberry Pi devices rather than assuming the
generic ISO will boot.

High-level flow:

1. Flash the current NixOS AArch64 SD image to an SD card.
2. Boot the Pi and SSH in or use a local keyboard/display.
3. Prepare the target disk with these labels:
   - `FIRMWARE`: vfat boot partition mounted at `/boot`.
   - `NIXOS`: Btrfs root partition containing `root` and `var-lib` subvolumes.
4. Clone this repo to `/home/joshan/.files`.
5. Copy the Home Assistant data into `/var/lib/...`.
6. Configure Dropbox/restic secrets in `/root/secrets`.
7. Run:

```sh
sudo nixos-rebuild switch --flake /home/joshan/.files#nixos-server
```

## Required Secret Files

Create these on the Pi before expecting backups or optional secret-backed
containers to work:

| File | Required when |
| --- | --- |
| `/root/secrets/restic-password` | Always, for Dropbox/restic backups |
| `/root/secrets/rclone.conf` | Always, for Dropbox/restic backups |
| `/root/secrets/openclaw.env` | Only when OpenClaw needs env-based secrets |
| `/root/secrets/twingate-connector.env` | Only when Twingate is enabled |

Do not commit these files. Keep a separate encrypted copy of them outside the
restic repository, such as a password manager secure note or later `sops-nix`
encrypted files in this private repo.

## Disk Layout

The checked-in hardware config expects:

```text
/dev/disk/by-label/FIRMWARE  vfat   /boot
/dev/disk/by-label/NIXOS     btrfs  /       subvol=root
/dev/disk/by-label/NIXOS     btrfs  /var/lib subvol=var-lib
```

That layout is deliberate:

- Nix/system rollback is done with Git plus `nixos-rebuild`.
- Home Assistant and container rollback is done by Snapper snapshots of
  `/var/lib`.
- Rolling back mutable data does not roll back the NixOS generation.

## Useful References

- NixOS on Raspberry Pi 4: https://wiki.nixos.org/wiki/NixOS_on_ARM/Raspberry_Pi_4
- NixOS on ARM: https://nixos.wiki/wiki/NixOS_on_ARM
- `nixos-rebuild build-vm`: https://wiki.nixos.org/wiki/NixOS%3Anixos-rebuild_build-vm
