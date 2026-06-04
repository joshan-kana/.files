# Installing NixOS On The Raspberry Pi 4

## Shape Of This Host

The flake has two server targets:

- `nixos-server`: the real Raspberry Pi 4 target, built for `aarch64-linux`.
- `nixos-server-vm`: an x86_64 VM target for testing the same service stack.

The real target does not import `/etc/nixos/hardware-configuration.nix`. Its
hardware/filesystem assumptions live in
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
