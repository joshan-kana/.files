# Install or recover `nixos-arm-parallels`

`nixos-arm-parallels` is an ARM64 NixOS VM running under Parallels Desktop.

## Current evaluated target

```sh
{{#include ../../generated/hosts/nixos-arm-parallels.sh}}
```

## Create and boot the VM

Create an ARM64 Linux VM in Parallels Desktop, attach a current ARM64 NixOS installer ISO, and boot it in UEFI mode.

Before modifying the virtual disk, confirm its device layout:

```sh
lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MOUNTPOINTS
```

The current hardware configuration expects:

- `/dev/sda1`: EFI system partition, VFAT, mounted at `/boot`;
- `/dev/sda2`: Btrfs filesystem mounted at `/home`;
- `/dev/sda3`: ext4 root filesystem mounted at `/`.

Choose partition sizes appropriate for the VM, then format and mount those three partitions under `/mnt` before continuing.

## Make the private repository available

Load an SSH key that can read `joshan-kana/.files`, then clone the repository into the target root:

```sh
{{#include ../../generated/hosts/nixos-arm-parallels.sh}}
sudo mkdir -p "/mnt$(dirname "$DOTFILES_REPO")"
sudo git clone --recurse-submodules \
  git@github.com:joshan-kana/.files.git \
  "/mnt$DOTFILES_REPO"
cd "/mnt$DOTFILES_REPO"
```

Compare a fresh hardware scan with the tracked Parallels hardware configuration before installing:

```sh
sudo nixos-generate-config --root /mnt --show-hardware-config \
  > /tmp/nixos-arm-parallels-hardware.nix
diff -u hosts/nixos-arm-parallels/hardware.nix \
  /tmp/nixos-arm-parallels-hardware.nix || true
```

## Install

```sh
sudo nixos-install \
  --option extra-experimental-features "nix-command flakes" \
  --flake ".#nixos-arm-parallels"
```

Reboot without the installer ISO, then verify:

```sh
hostname
findmnt -T /
findmnt -T /boot
findmnt -T /home
systemctl --failed --no-pager
```

Restore the host's backup bootstrap credentials and `~/.secrets` before relying on its scheduled secret backup.
