# Installation guide for `nixos-arm-parallels`

`nixos-arm-parallels` is an ARM64 NixOS VM running under Parallels Desktop.

## Current evaluated target

Load the generated target environment once in the installer shell before using commands below that reference these values:

```sh
{{#include ../../generated/hosts/nixos-arm-parallels.sh}}
```

If practical, enable [NixOS installer SSH](../common/nixos-installer-ssh.md) after networking is available and continue the installation remotely.

## Create and boot the VM

Create an ARM64 Linux VM in Parallels Desktop, attach a current ARM64 NixOS installer ISO, and boot it in UEFI mode.

Before modifying the virtual disk, confirm its device layout:

```sh
lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MOUNTPOINTS
```

Use the evaluated `BOOT_DEVICE`, `HOME_DEVICE` and `ROOT_DEVICE` and their corresponding filesystem types from the target environment above. Choose appropriate partition sizes, confirm the devices match the VM's disk, then format and mount them at `/mnt/boot`, `/mnt/home` and `/mnt` respectively (mount the root first).

{{#include ../_shared/restore-secrets-and-clone.inc}}

Compare a fresh hardware scan with the tracked Parallels hardware configuration before installing:

```sh
sudo nixos-generate-config --root /mnt --show-hardware-config \
  > "/tmp/$HOST_NAME-hardware.nix"
diff -u "hosts/$HOST_NAME/hardware.nix" \
  "/tmp/$HOST_NAME-hardware.nix" || true
```

## Install

```sh
sudo nixos-install \
  --option extra-experimental-features "nix-command flakes" \
  --flake ".#$HOST_NAME"
```

{{#include ../_shared/finalize-bare-install.inc}}

Reboot without the installer ISO and reload the generated target environment:

```sh
{{#include ../../generated/hosts/nixos-arm-parallels.sh}}
```

Then verify:

```sh
hostname
findmnt -T /
findmnt -T /boot
findmnt -T /home
systemctl --failed --no-pager
```

{{#include ../_shared/secrets-backup-first-boot.inc}}
