# Installation guide for `nixos`

The `nixos` x86_64 configuration currently contains a placeholder hardware file for evaluation only. Do not install or switch this profile until the real target machine is available and `hosts/nixos/hardware.nix` has been regenerated from that machine.

## Current evaluated target

Load the generated target environment once in the installer shell before using commands below that reference these values:

```sh
{{#include ../../generated/hosts/nixos.sh}}
```

If practical, enable [NixOS installer SSH](../common/nixos-installer-ssh.md) after networking is available and continue the installation remotely.

## Prepare the target

Boot a current x86_64 NixOS installer in UEFI mode. Inspect the target disks before partitioning:

```sh
lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MODEL,SERIAL,TRAN,MOUNTPOINTS
```

Partition, format, and mount the target filesystems under `/mnt`, including the EFI system partition required by systemd-boot.

{{#include ../_shared/restore-secrets-and-clone.inc}}

Generate the real hardware configuration directly into the checkout:

```sh
sudo nixos-generate-config --root /mnt --show-hardware-config \
  | sudo tee hosts/nixos/hardware.nix >/dev/null
```

Review the generated filesystem, boot, CPU, and kernel-module settings before installing. The placeholder warning must be gone from `hosts/nixos/hardware.nix`.

## Install

```sh
sudo nixos-install \
  --option extra-experimental-features "nix-command flakes" \
  --flake ".#nixos"
```

{{#include ../_shared/finalize-bare-install.inc}}

Reboot from the installed disk and reload the generated target environment:

```sh
{{#include ../../generated/hosts/nixos.sh}}
```

Then verify:

```sh
hostname
findmnt -T /
systemctl --failed --no-pager
```
