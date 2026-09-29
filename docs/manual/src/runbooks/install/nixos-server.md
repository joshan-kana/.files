# Install or recover `nixos-server`

This guide installs the current `nixos-server` configuration on the Dell
OptiPlex 7010 SFF from a NixOS installer. Keep the Vault HDDs disconnected while
the installer modifies the internal system disk. After `nixos-install` succeeds,
shut down, connect the Vault HDDs, and boot the installed system.

## Current evaluated target values

The built manual injects these values from `nixosConfigurations.nixos-server`. Load this generated environment once in the installer shell:

```sh
{{#include ../../generated/server-env.sh}}
```

Commands below that use these variables assume the block has been loaded in the current shell.

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
sudo mkdir -p /mnt/boot "$(dirname "/mnt$APP_DATA_ROOT")"
sudo mount /dev/disk/by-label/BOOT /mnt/boot
sudo btrfs subvolume create "/mnt$APP_DATA_ROOT"

findmnt -T /mnt
findmnt -T /mnt/boot
sudo btrfs subvolume list /mnt
```

## Restore Bootstrap Credentials

Retrieve the backup bootstrap material from the external recovery store. The
current Nix backup configuration is the source of truth for credential locations
and repository settings.

Stage the credentials with root-only permissions at the configured target
locations, then set the installer-shell variables below from that same
configuration:

```sh
export RCLONE_CONFIG=<mounted-target-rclone-config>
export SECRETS_PASSWORD_FILE=<mounted-target-secrets-password-file>
export SECRETS_REPOSITORY=<configured-secrets-repository>
```

Restore the latest secrets snapshot:

```sh
sudo env RCLONE_CONFIG="$RCLONE_CONFIG" \
  nix --extra-experimental-features "nix-command flakes" shell \
  nixpkgs#restic nixpkgs#rclone -c restic \
  -r "$SECRETS_REPOSITORY" \
  --password-file "$SECRETS_PASSWORD_FILE" \
  restore latest --target /mnt
```

Verify the restored primary-user secret tree and Unix account state before
continuing. The secrets snapshot carries the account database so user and group
identities and password hashes are retained across reinstalls.

## Clone The Configuration

Clone the repository using the restored GitHub SSH key:

```sh
sudo env \
  GIT_SSH_COMMAND="ssh -i /mnt$USER_SECRETS_DIR/id_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
  git clone --recurse-submodules \
  git@github.com:joshan-kana/.files.git \
  "/mnt$DOTFILES_REPO"
```

## Restore Application Data

Now that the repository is available, derive the app-backup settings directly
from the target configuration instead of copying them into this guide:

```sh
cd "/mnt$DOTFILES_REPO"

nix_eval() {
  sudo nix --extra-experimental-features "nix-command flakes" eval --raw \
    ".#nixosConfigurations.nixos-server.$1"
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
kept in [Backup restore](../../operations/backup-restore.md).

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

After `nixos-install` succeeds, shut down the installer, connect the Vault HDDs,
and boot from the internal NVMe. The configured Vault pool should import and
mount automatically during normal boot.

In the new shell, reload the generated environment:

```sh
{{#include ../../generated/server-env.sh}}
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
sudo restic-secrets snapshots --latest 1
sudo restic-apps snapshots --latest 1
systemctl is-system-running || true
systemctl --failed --no-pager
```

If the Vault pool was not imported or mounted, use
[Vault / ZFS recovery](../../operations/vault-recovery.md) to inspect and import
the existing pool. Do not recreate the pool as a recovery step.

Fix ownership of the restored user files if needed:

```sh
sudo chown -R "$PRIMARY_USER:users" "$DOTFILES_REPO" "$USER_SECRETS_DIR"
```

Once the base system and Vault storage are healthy, restore any remaining
application-managed or database-backed state using
[Backup restore](../../operations/backup-restore.md). Stop writers before
replacing mutable application state.
