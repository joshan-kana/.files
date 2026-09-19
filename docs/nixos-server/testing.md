# Server Test Notes

Use these checks when changing or reinstalling the physical `nixos-server`
host. Evaluation and build validation are repository checks; hardware and
storage checks are completed on the OptiPlex before production cutover.

## Repository Evaluation

From the macOS worktree:

```sh
nix fmt

git diff --check

nix flake show
nix eval .#nixosConfigurations.nixos-server.config.nixpkgs.hostPlatform.system
nix eval .#nixosConfigurations.nixos-server.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.nixos-server.config.fileSystems --json
nix eval .#nixosConfigurations.nixos-server.config.boot.initrd.availableKernelModules --json
```

Expected server platform:

```text
"x86_64-linux"
```

The filesystem evaluation must resolve the root and EFI mounts through
`/dev/disk/by-label/ROOT` and `/dev/disk/by-label/BOOT`.

## Build Validation

Build the production closure on an x86_64 Linux builder:

```sh
nix build .#nixosConfigurations.nixos-server.config.system.build.toplevel --no-link
```

Run the full repository validation before review:

```sh
nix flake check
```

The container lock must also be valid for `linux/amd64`; the repository's
`update-container-lock` command derives the required platform from the host
configuration.

## Pre-install Hardware Check

From the NixOS installer on the OptiPlex:

```sh
lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MODEL,SERIAL,TRAN,MOUNTPOINTS
lspci -nnk
ip -br link
```

After mounting the target `ROOT` and `BOOT` filesystems under `/mnt`, compare a
fresh hardware scan with `hosts/nixos-server/hardware.nix`:

```sh
sudo nixos-generate-config --root /mnt
cat /mnt/etc/nixos/hardware-configuration.nix
```

Generated filesystem UUIDs are not copied into the repository. Keep the
label-based mounts from the committed hardware configuration.

## First-boot Validation

Boot with the external Vault HDDs still disconnected and verify:

```sh
findmnt / /boot /var/lib/apps
lsblk -f
ip -br link
systemctl is-system-running || true
systemctl --failed --no-pager
```

Confirm the wired interface matches `dotfiles.server.lan.interface` before
moving the production addresses to the OptiPlex.

## Vault Import Validation

After the Pi has exported `vault` cleanly and is powered down, connect both Vault
HDDs and inspect before importing:

```sh
lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MODEL,SERIAL,TRAN,MOUNTPOINTS
sudo zpool import
sudo zpool import vault
zpool status -x vault
zpool status vault
zfs list -r vault
zfs list -t snapshot -r vault
findmnt /srv/vault /var/lib/atticd
```

Do not recreate, format, or wipe either Vault member during migration.
