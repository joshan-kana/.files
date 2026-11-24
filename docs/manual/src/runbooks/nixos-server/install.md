# Installation guide for `nixos-server`

This guide installs the current `nixos-server` configuration on the Dell
OptiPlex 7010 SFF from a NixOS installer. Keep the Vault HDDs disconnected while
the installer modifies the internal system disk. After `nixos-install` succeeds,
shut down, connect the Vault HDDs, and boot the installed system.

## Current evaluated target values

The built manual injects these values from `nixosConfigurations.nixos-server`. Load this generated environment once in the installer shell:

```sh
{{#include ../../generated/hosts/nixos-server.sh}}
```

Commands below that use these variables assume the block has been loaded in the current shell.

If practical, enable [NixOS installer SSH](../common/nixos-installer-ssh.md) after networking is available and continue the installation remotely.

## Prepare The Target

Boot a current x86_64 NixOS installer in UEFI mode, then verify the internal
system disk and network interface before changing anything:

```sh
lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MODEL,SERIAL,TRAN,MOUNTPOINTS
ip -br link
```

Select the internal NVMe system disk after verifying its identity above. The next command destroys its existing partition table. Keep the data disks disconnected. The procedure uses the evaluated boot and root filesystem labels and assumes the configured VFAT/Btrfs layout.

```sh
read -r -p "Verified internal NVMe system disk: " DISK
[[ "$DISK" =~ ^/dev/nvme[0-9]+n[0-9]+$ ]] && [[ "$(lsblk -dn -o TYPE "$DISK")" == disk ]] || exit 1
[[ "$BOOT_DEVICE" == /dev/disk/by-label/* && "$ROOT_DEVICE" == /dev/disk/by-label/* ]] || exit 1
[[ "$BOOT_FS" == vfat && "$ROOT_FS" == btrfs ]] || exit 1

sudo parted --script "$DISK" -- \
  mklabel gpt \
  mkpart ESP fat32 1MiB 1025MiB \
  set 1 esp on \
  mkpart ROOT btrfs 1025MiB 100% || exit 1

sudo udevadm settle
sudo mkfs.fat -F 32 -n "${BOOT_DEVICE##*/}" "${DISK}p1"
sudo mkfs.btrfs -f -L "${ROOT_DEVICE##*/}" "${DISK}p2"
```

Mount the target and create the application-data subvolume:

```sh
sudo mount "$ROOT_DEVICE" /mnt
sudo mkdir -p /mnt/boot "$(dirname "/mnt$APP_DATA_ROOT")"
sudo mount "$BOOT_DEVICE" /mnt/boot
sudo btrfs subvolume create "/mnt$APP_DATA_ROOT"

findmnt -T /mnt
findmnt -T /mnt/boot
sudo btrfs subvolume list /mnt
```

{{#include ../_shared/restore-secrets-and-clone.inc}}

## Restore Application Data

Now that the repository is available, derive the app-backup settings directly
from the target configuration instead of copying them into this guide:

```sh
cd "/mnt$DOTFILES_REPO"

nix_eval() {
  sudo nix --extra-experimental-features "nix-command flakes" eval --raw \
    ".#nixosConfigurations.$HOST_NAME.$1"
}

export APPS_REPOSITORY="$(nix_eval config.services.restic.backups.apps.repository)"
export APPS_PASSWORD_FILE="/mnt$(nix_eval config.services.restic.backups.apps.passwordFile)"
export RCLONE_CONFIG="/mnt$(nix_eval config.services.restic.backups.apps.rcloneConfigFile)"
export APP_DATA_ROOT="$(nix_eval config.dotfiles.server.storage.appData.root)"

sudo env RCLONE_CONFIG="$RCLONE_CONFIG" \
  nix --extra-experimental-features "nix-command flakes" shell \
  nixpkgs#restic nixpkgs#rclone -c restic \
  -r "$APPS_REPOSITORY" \
  --password-file "$APPS_PASSWORD_FILE" \
  restore latest --target /mnt --include "$APP_DATA_ROOT"
```

Backup creation, repository maintenance, and selective recovery procedures are
kept in [Backup / application recovery](backup-recovery.md).

Some services keep mutable application-managed state outside the Nix
configuration. Restoring the server application-data backup before first boot
preserves that state without duplicating it declaratively in this runbook.

## Check Hardware Detection

Generate a hardware scan against the mounted target and compare its detected
kernel/initrd modules and CPU settings with `hosts/nixos-server/hardware.nix`:

```sh
sudo nixos-generate-config --root /mnt
cat /mnt/etc/nixos/hardware-configuration.nix
```

## Install NixOS

Derive the bootstrap binary-cache settings from the target configuration:

```sh
cd "/mnt$DOTFILES_REPO"

substituters="$(
  sudo nix --extra-experimental-features "nix-command flakes" eval --raw \
    ".#nixosConfigurations.$HOST_NAME" \
    --apply 'cfg: builtins.concatStringsSep " " (cfg.pkgs.lib.unique cfg.config.nix.settings.substituters)'
)"
trusted_public_keys="$(
  sudo nix --extra-experimental-features "nix-command flakes" eval --raw \
    ".#nixosConfigurations.$HOST_NAME" \
    --apply 'cfg: builtins.concatStringsSep " " (cfg.pkgs.lib.unique cfg.config.nix.settings.trusted-public-keys)'
)"
```

Install the target:

```sh
sudo nixos-install \
  --option extra-experimental-features "nix-command flakes" \
  --option extra-substituters "$substituters" \
  --option extra-trusted-public-keys "$trusted_public_keys" \
  --flake ".#$HOST_NAME"
```

{{#include ../_shared/finalize-bare-install.inc}}

## First Boot

After `nixos-install` succeeds, shut down the installer, connect the Vault HDDs,
and boot from the internal NVMe. The configured Vault pool should import and
mount automatically during normal boot.

In the new shell, reload the generated environment:

```sh
{{#include ../../generated/hosts/nixos-server.sh}}
```

Verify the installed filesystems, Vault pool, network, restored backups, and
failed units:

```sh
findmnt -T /
findmnt -T /boot
findmnt -T "$APP_DATA_ROOT"
zpool status "$VAULT_POOL"
zfs list -r "$VAULT_POOL"
findmnt -T "$VAULT_ROOT"
lsblk -f
ip -br addr
run0 restic-apps snapshots --latest 1
systemctl is-system-running || true
systemctl --failed --no-pager
```

If the Vault pool was not imported or mounted, use
[Vault / ZFS recovery](vault-zfs-recovery.md) to inspect and import
the existing pool. Do not recreate the pool as a recovery step.

Once the base system and Vault storage are healthy, restore any remaining
application-managed or database-backed state using
[Backup / application recovery](backup-recovery.md). Stop writers before
replacing mutable application state.

{{#include ../_shared/secrets-backup-first-boot.inc}}
