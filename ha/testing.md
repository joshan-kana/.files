# Server Test Notes

These checks were run before installing on the Raspberry Pi.

## Evaluation

From the macOS worktree:

```sh
nix eval --impure .#nixosConfigurations.nixos-server.config.system.name
nix eval --impure .#nixosConfigurations.nixos-server.config.nixpkgs.hostPlatform.system
nix eval --impure .#nixosConfigurations.nixos-server.config.services.restic.backups.home-assistant.repository
nix eval --impure .#nixosConfigurations.nixos-server-vm.config.system.name
```

Expected results:

```text
"nixos-server"
"aarch64-linux"
"rclone:dropbox:Backups/nixos-home-assistant/restic"
"nixos-server-vm"
```

## VM Build

The macOS host cannot build Linux VM derivations directly, so the VM build was
run inside the local OrbStack NixOS machine:

```sh
orb sh -lc 'cd /Users/joshan/.files-nixos-server && nixos-rebuild build-vm --flake .#nixos-server-vm'
```

This completed successfully and produced a runnable VM:

```text
run-nixos-server-vm-vm
```

## Real Pi Target Build

The real Raspberry Pi target was also built from OrbStack without producing a
local `result` symlink:

```sh
orb sh -lc 'cd /Users/joshan/.files-nixos-server && nix build .#nixosConfigurations.nixos-server.config.system.build.toplevel --no-link'
```

This completed successfully and built the production system closure, including
the Snapper and restic units.
