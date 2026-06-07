# Server Test Notes

These checks were run before installing on the Raspberry Pi.

## Evaluation

From the macOS worktree:

```sh
nix eval --impure .#nixosConfigurations.nixos-server.config.system.name
nix eval --impure .#nixosConfigurations.nixos-server.config.system.nixos.release
nix eval --impure .#nixosConfigurations.nixos-server.config.boot.kernelPackages.kernel.version
nix eval --impure .#nixosConfigurations.nixos-server.config.nixpkgs.hostPlatform.system
nix eval --impure .#nixosConfigurations.nixos-server.config.services.restic.backups.home-assistant.repository
```

Expected results:

```text
"nixos-server"
"26.05"
"6.18.34"
"aarch64-linux"
"rclone:dropbox:Backups/nixos-home-assistant/restic"
```

The configured substituters were also evaluated:

```sh
nix eval --impure --json .#nixosConfigurations.nixos-server.config.nix.settings.substituters
```

Expected result:

```json
["https://cache.nixos.org/","https://nix-community.cachix.org","https://nixos-raspberrypi.cachix.org"]
```

## Binary Cache Check

The kernel was tested with local builds disabled:

```sh
orb sh -lc 'cd /Users/joshan/.files-nixos-server && nix build .#nixosConfigurations.nixos-server.config.boot.kernelPackages.kernel --no-link --option max-jobs 0 --option fallback false --option substituters "https://cache.nixos.org/ https://nix-community.cachix.org https://nixos-raspberrypi.cachix.org" --option trusted-public-keys "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="'
```

This fetched `linux-6.18.34` from `https://cache.nixos.org`.

## VM Build

The macOS host cannot build Linux VM derivations directly, so the VM build was
run inside the local OrbStack NixOS machine:

```sh
orb sh -lc 'cd /Users/joshan/.files-nixos-server && nixos-rebuild build-vm --flake .#nixos-server'
```

This completed successfully and produced a runnable VM:

```text
run-nixos-server-vm
```

## Real Pi Target Build

The real Raspberry Pi target was also built from OrbStack without producing a
local `result` symlink:

```sh
orb sh -lc 'cd /Users/joshan/.files-nixos-server && nix build .#nixosConfigurations.nixos-server.config.system.build.toplevel --no-link'
```

This completed successfully and built the production system closure, including
the Snapper and restic units.

## Real Pi Boot Validation

The flashed image has been tested on the Raspberry Pi 4. UART output confirmed
that U-Boot loaded `extlinux`, the generic cached kernel, the initrd, and the
board device tree from the FAT `FIRMWARE` partition.

The final boot fix was to keep boot files on `/boot`, mount the Btrfs top-level
as `/`, and let the repart image module use its default `/nix/store` prefix.
Setting a custom store prefix placed store paths in the wrong location and made
`initrd-find-nixos-closure.service` fail.

Successful first-boot signs:

```sh
ssh-keygen -R 192.168.1.3 >/dev/null 2>&1 || true
ssh joshan@192.168.1.3 true
```

Useful post-boot checks:

```sh
findmnt / /boot /var/lib
lsblk -f
systemctl is-system-running || true
```
