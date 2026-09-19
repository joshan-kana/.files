# NixOS Server Install Guide

This guide installs the current `nixos-server` configuration on the Dell
OptiPlex 7010 SFF from a NixOS installer. Keep the Vault HDDs disconnected until
the installed system has booted successfully.

## Prepare The Target

Boot a current x86_64 NixOS installer in UEFI mode, then verify the internal
system disk and network interface before changing anything:

```sh
lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MODEL,SERIAL,TRAN,MOUNTPOINTS
ip -br link
```

The commands below use `/dev/nvme0n1` as the system disk and destroy its existing
partition table.

```sh
export DISK=/dev/nvme0n1

sudo parted --script "$DISK" -- \
  mklabel gpt \
  mkpart ESP fat32 1MiB 1025MiB \
  set 1 esp on \
  mkpart ROOT btrfs 1025MiB 100%

sudo mkfs.fat -F 32 -n BOOT "${DISK}p1"
sudo mkfs.btrfs -f -L ROOT "${DISK}p2"
```

Mount the target and create the application-data subvolume:

```sh
sudo mount /dev/disk/by-label/ROOT /mnt
sudo mkdir -p /mnt/boot /mnt/var/lib
sudo mount /dev/disk/by-label/BOOT /mnt/boot
sudo btrfs subvolume create /mnt/var/lib/apps

findmnt /mnt /mnt/boot
sudo btrfs subvolume list /mnt
```

## Restore Bootstrap Credentials

Copy the recovery `rclone.conf` and `secrets-restic-password` to `/tmp` on the
installer, then install them into the mounted target:

```sh
sudo install -d -m 700 /mnt/var/lib/backup-credentials
sudo install -m 600 -o root -g root /tmp/rclone.conf \
  /mnt/var/lib/backup-credentials/rclone.conf
sudo install -m 600 -o root -g root /tmp/secrets-restic-password \
  /mnt/var/lib/backup-credentials/secrets-restic-password
rm -f /tmp/rclone.conf /tmp/secrets-restic-password
```

Restore the latest secrets snapshot:

```sh
sudo env RCLONE_CONFIG=/mnt/var/lib/backup-credentials/rclone.conf \
  nix --extra-experimental-features "nix-command flakes" shell \
  nixpkgs#restic nixpkgs#rclone -c restic \
  -r rclone:dropbox:Archives/Backups/secrets/nixos-server \
  --password-file /mnt/var/lib/backup-credentials/secrets-restic-password \
  restore latest --target /mnt

sudo test -f /mnt/root/secrets/id_ed25519
sudo test -d /mnt/home/joshan/.secrets
```

Restore the latest application-data snapshot before the system build:

```sh
sudo env RCLONE_CONFIG=/mnt/var/lib/backup-credentials/rclone.conf \
  nix --extra-experimental-features "nix-command flakes" shell \
  nixpkgs#restic nixpkgs#rclone -c restic \
  -r rclone:dropbox:Archives/Backups/nixos-server \
  --password-file /mnt/root/secrets/restic-password \
  restore latest --target /mnt --include /var/lib/apps
```

Backup creation, repository maintenance, and selective recovery procedures are
kept in [Backup And Restore](backup-restore.md).

## Check Hardware Detection

Generate a hardware scan against the mounted target and compare its detected
kernel/initrd modules and CPU settings with `hosts/nixos-server/hardware.nix`:

```sh
sudo nixos-generate-config --root /mnt
cat /mnt/etc/nixos/hardware-configuration.nix
```

The committed configuration owns the `ROOT` and `BOOT` filesystem mounts.

## Install NixOS

Clone the repository using the restored GitHub SSH key:

```sh
sudo env \
  GIT_SSH_COMMAND='ssh -i /mnt/root/secrets/id_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new' \
  git clone --recurse-submodules \
  git@github.com:joshan-kana/.files.git \
  /mnt/home/joshan/.files
```

Derive the bootstrap binary-cache settings from the target configuration:

```sh
cd /mnt/home/joshan/.files

substituters="$(
  sudo nix --extra-experimental-features "nix-command flakes" eval --raw \
    .#nixosConfigurations.nixos-server \
    --apply 'cfg: builtins.concatStringsSep " " (cfg.pkgs.lib.unique cfg.config.nix.settings.substituters)'
)"
trusted_public_keys="$(
  sudo nix --extra-experimental-features "nix-command flakes" eval --raw \
    .#nixosConfigurations.nixos-server \
    --apply 'cfg: builtins.concatStringsSep " " (cfg.pkgs.lib.unique cfg.config.nix.settings.trusted-public-keys)'
)"
```

Install the target:

```sh
sudo nixos-install \
  --option extra-experimental-features "nix-command flakes" \
  --option extra-substituters "$substituters" \
  --option extra-trusted-public-keys "$trusted_public_keys" \
  --flake .#nixos-server
```

## First Boot

Reboot from the internal NVMe with the Vault HDDs still disconnected. Then check
the filesystems, network, restored backups, and failed units:

```sh
findmnt / /boot /var/lib/apps
lsblk -f
ip -br addr
sudo restic-secrets snapshots --latest 1
sudo restic-apps snapshots --latest 1
systemctl is-system-running || true
systemctl --failed --no-pager
```

Fix ownership of the restored user files if needed:

```sh
sudo chown -R joshan:users /home/joshan/.files /home/joshan/.secrets
```

After the base system is healthy, connect the Vault HDDs and follow
[Vault ZFS Storage](vault-storage.md) to import and verify the existing pool.
