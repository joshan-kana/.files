# NixOS Server Install Guide

This guide installs the `nixos-server` configuration onto the Dell OptiPlex
7010 SFF. The internal NVMe is the system disk. The existing two-drive `vault`
ZFS mirror is preserved and stays disconnected until the base system is
installed and ready for storage migration.

## Final Layout

- NixOS host: `192.168.1.3`
- AdGuard: `192.168.1.2`
- Router: `192.168.1.1`
- Repo: `/home/joshan/.files`
- App data root: `/var/lib/apps`
- Runtime secrets: `/root/secrets`
- EFI system partition: FAT32 label `BOOT`, mounted at `/boot`
- Root filesystem: Btrfs label `ROOT`
- `/var/lib/apps`: Btrfs subvolume on the root filesystem
- External Vault: existing ZFS mirror mounted at `/srv/vault`

The system disk uses stable filesystem labels:

- `ROOT` for the Btrfs root filesystem.
- `BOOT` for the FAT32 EFI system partition.

## Before You Start

- Disconnect both Vault HDDs. Only the internal NVMe should be available to the
  partitioning commands below.
- Boot a current x86_64 NixOS installer in UEFI mode.
- The current internal disk is `/dev/nvme0n1` and contains the previous Windows
  installation. The procedure below destroys that installation.
- Keep the Raspberry Pi and its SD card unchanged until the replacement server
  has passed live validation.

Before modifying the disk, verify the target:

```sh
lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MODEL,SERIAL,TRAN,MOUNTPOINTS
ip -br link
```

The onboard Ethernet interface is configured as `enp0s31f6`. Confirm that name from
the installer before deployment; if the live machine reports a different name,
change `dotfiles.server.lan.interface` before installing.

## Backup Recovery Kit

Normal replacement installs do not need a manually maintained copy of every
runtime secret. The external recovery store keeps only the two bootstrap files
needed to reach the encrypted secrets repository:

```text
rclone.conf
secrets-restic-password
```

The recovery `rclone.conf` must contain a Dropbox remote named `dropbox`. Its
long-lived refresh token is the durable credential; the cached access token may
be expired. Rclone refreshes that access token when the config is used, so the
external recovery copy does not need to track normal token refreshes.

The secrets repository is:

```text
rclone:dropbox:Archives/Backups/secrets/nixos-server
```

It contains the current backed-up state of:

```text
/root/secrets
/home/joshan/.secrets
/var/lib/userborn
```

On a replacement machine, install the two recovery files under
`/var/lib/backup-credentials`, restore the secrets repository, then restore the
larger app-data repository. Do not maintain a second full plaintext secrets
bundle on another machine.

### First-time recovery-kit creation

This is only needed if no external recovery kit exists yet. Configure Dropbox
with a remote named exactly `dropbox`:

```sh
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#rclone -c rclone config
```

Use browser authorization when prompted. Keep Full Dropbox access if the backup
repositories must remain under `Archives/Backups/`. Save a recovery copy of the
resulting `rclone.conf` in the external recovery store.

Generate a unique password for the `nixos-server` secrets repository and save
that password in the same external recovery kit. Do not reuse the application
data repository password.

For the one-time migration from an existing live server, install those two
bootstrap files locally, initialize `restic-secrets`, and take the first backup
as described in `backup-restore.md`. After that first snapshot, replacement
installs recover the runtime secret directories from Restic instead of manually
reconstructing them.

A truly new deployment with no previous secrets repository must create its
runtime credentials once before taking that first snapshot. That is initial
service provisioning, not part of the normal disaster-recovery path.

### First-time runtime-secret provisioning

For a genuinely new server with no secrets snapshot to restore, create
`/root/secrets` with mode `0700` and put the required service credentials there
before taking the first secrets backup. At minimum, preserve the existing
service-specific filenames expected by the NixOS configuration.

For Tailscale, configure the tailnet policy before creating the OAuth client:

```json
{
  "tagOwners": {
    "tag:nixos-server": [
      "autogroup:admin"
    ]
  },
  "autoApprovers": {
    "routes": {
      "192.168.1.0/24": [
        "tag:nixos-server"
      ]
    }
  }
}
```

In the Tailscale admin console, create an OAuth client with `auth_keys` and
`devices:core` write scopes, restrict it to `tag:nixos-server`, and install the
client ID and secret as:

```text
/root/secrets/tailscale-oauth-client-id
/root/secrets/tailscale-oauth-client-secret
```

`n8n.env` must contain a durable `N8N_ENCRYPTION_KEY`, and other enabled services
must have the runtime files required by their modules. Keep all files under
`/root/secrets` mode `0600`. Once the initial set is complete, take the first
`restic-secrets` snapshot; future replacement installs restore these files from
that repository instead of provisioning them again.

## Prepare The NVMe

Create a GPT with a 1 GiB EFI system partition and use the remainder for Btrfs:

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

Mount the filesystems exactly as the committed host configuration expects, then
create the application-data subvolume required by Snapper:

```sh
sudo mount /dev/disk/by-label/ROOT /mnt
sudo mkdir -p /mnt/boot /mnt/var/lib
sudo mount /dev/disk/by-label/BOOT /mnt/boot
sudo btrfs subvolume create /mnt/var/lib/apps

findmnt /mnt /mnt/boot
sudo btrfs subvolume list /mnt
```

## Stage Bootstrap Credentials

The installed system reads the recovery bootstrap files from
`/var/lib/backup-credentials`. Copy them into the mounted target before
installation.

From the source machine:

```sh
export INSTALLER="<installer-ip>"
export RECOVERY_RCLONE_CONFIG="/path/to/temporary/rclone.conf"
export SECRETS_RESTIC_PASSWORD_FILE="/path/to/temporary/secrets-restic-password"

scp "$RECOVERY_RCLONE_CONFIG" "$SECRETS_RESTIC_PASSWORD_FILE" \
  "nixos@$INSTALLER:/tmp/"
```

On the installer:

```sh
sudo install -d -m 700 /mnt/var/lib/backup-credentials
sudo install -m 600 -o root -g root /tmp/rclone.conf \
  /mnt/var/lib/backup-credentials/rclone.conf
sudo install -m 600 -o root -g root /tmp/secrets-restic-password \
  /mnt/var/lib/backup-credentials/secrets-restic-password
rm -f /tmp/rclone.conf /tmp/secrets-restic-password
```

Remove any temporary source-machine copies after the transfer.

## Restore Secrets

Restore the latest secrets snapshot directly into the mounted target:

```sh
sudo env RCLONE_CONFIG=/mnt/var/lib/backup-credentials/rclone.conf \
  nix --extra-experimental-features "nix-command flakes" shell \
  nixpkgs#restic nixpkgs#rclone -c restic \
  -r rclone:dropbox:Archives/Backups/secrets/nixos-server \
  --password-file /mnt/var/lib/backup-credentials/secrets-restic-password \
  snapshots

sudo env RCLONE_CONFIG=/mnt/var/lib/backup-credentials/rclone.conf \
  nix --extra-experimental-features "nix-command flakes" shell \
  nixpkgs#restic nixpkgs#rclone -c restic \
  -r rclone:dropbox:Archives/Backups/secrets/nixos-server \
  --password-file /mnt/var/lib/backup-credentials/secrets-restic-password \
  restore latest --target /mnt

sudo test -f /mnt/root/secrets/id_ed25519
sudo test -d /mnt/home/joshan/.secrets
```

## Verify Hardware Detection

Generate a fresh hardware scan after the target filesystems are mounted:

```sh
sudo nixos-generate-config --root /mnt
cat /mnt/etc/nixos/hardware-configuration.nix
```

`hosts/nixos-server/hardware.nix` contains the OptiPlex kernel/initrd modules,
Intel CPU microcode configuration, and the `ROOT` and `BOOT` filesystem mounts.
A fresh `nixos-generate-config --root /mnt` scan is used to check detected
hardware before installation.

## Install The Flake

Clone the deployment branch with the restored GitHub SSH key:

```sh
sudo env GIT_SSH_COMMAND='ssh -i /mnt/root/secrets/id_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new' \
  git clone --recurse-submodules \
  --branch migrate/optiplex-server \
  git@github.com:joshan-kana/.files.git \
  /mnt/home/joshan/.files
```

Verify the checkout, derive the binary-cache settings from the target
configuration, and install `nixos-server`:

```sh
sudo git -C /mnt/home/joshan/.files status --short --branch
sudo test -f /mnt/home/joshan/.files/docs/infrastructure-docs/README.md

substituters="$(
  sudo nix --extra-experimental-features "nix-command flakes" eval --raw \
    /mnt/home/joshan/.files#nixosConfigurations.nixos-server \
    --apply 'cfg: builtins.concatStringsSep " " (cfg.pkgs.lib.unique cfg.config.nix.settings.substituters)'
)"
trusted_public_keys="$(
  sudo nix --extra-experimental-features "nix-command flakes" eval --raw \
    /mnt/home/joshan/.files#nixosConfigurations.nixos-server \
    --apply 'cfg: builtins.concatStringsSep " " (cfg.pkgs.lib.unique cfg.config.nix.settings.trusted-public-keys)'
)"

sudo nixos-install \
  --option extra-experimental-features "nix-command flakes" \
  --option extra-substituters "$substituters" \
  --option extra-trusted-public-keys "$trusted_public_keys" \
  --flake /mnt/home/joshan/.files#nixos-server
```

Do not connect or import the Vault drives during this step.

## First Boot

1. Reboot from the internal NVMe with the Vault HDDs still disconnected.
2. Confirm `/` comes from `ROOT` and `/boot` comes from `BOOT`.
3. Confirm the wired interface name and static network profile.
4. Restore application data.
5. Only after the base host is validated, follow
   [Vault ZFS Storage](vault-storage.md) to move/import the existing pool.

Fix the staged checkout ownership after the configured user exists:

```sh
sudo chown -R joshan:users /home/joshan/.files
```

Useful checks:

```sh
findmnt / /boot /var/lib/apps
lsblk -f
ip -br link
systemctl is-system-running || true
systemctl --failed --no-pager
```

## Verify Restored Secrets

The secrets snapshot is already restored under `/root/secrets` and
`/home/joshan/.secrets`. Verify the configured wrapper can read the repository:

```sh
ssh -t "joshan@$SERVER" 'sudo restic-secrets snapshots'
```

## Restore Mutable App Data

For a replacement NixOS server with an existing restic backup, restore the app
data root directly. The restic repository contains `/var/lib/apps`, so no app
names need to be listed here:

```sh
ssh -t "$SERVER" '
  sudo env RCLONE_CONFIG=/var/lib/backup-credentials/rclone.conf \
    restic -r rclone:dropbox:Archives/Backups/nixos-server \
    --password-file /root/secrets/restic-password \
    restore latest \
    --target / \
    --include /var/lib/apps
'
```

For a one-time HAOS backup migration, use `docs/nixos-server/migration.md`.

## First Rebuild

After restoring the application data, run the first rebuild
with the target configuration's binary caches passed
as extra Nix options. The command evaluates the substituters and signing keys
from the `nixos-server` configuration:

```sh
cd /home/joshan/.files

substituters="$(
  nix eval --raw .#nixosConfigurations.nixos-server \
    --apply 'cfg: builtins.concatStringsSep " " (cfg.pkgs.lib.unique cfg.config.nix.settings.substituters)'
)"
trusted_public_keys="$(
  nix eval --raw .#nixosConfigurations.nixos-server \
    --apply 'cfg: builtins.concatStringsSep " " (cfg.pkgs.lib.unique cfg.config.nix.settings.trusted-public-keys)'
)"

sudo nixos-rebuild switch --flake .#nixos-server \
  --option extra-substituters "$substituters" \
  --option extra-trusted-public-keys "$trusted_public_keys"
```

Normal later rebuilds use the Nix settings already installed by the system and
do not need these bootstrap options.

## Verify The System

Run a short base-system check on the OptiPlex:

```sh
ssh joshan@192.168.1.3 '
  hostname
  findmnt / /boot /var/lib
  systemctl is-system-running || true
  systemctl --failed --no-pager
'
```

Check the main endpoints from the user's machine after restore and rebuild:

```sh
curl -I http://192.168.1.3:8123
curl -I http://192.168.1.2:3000
curl -I http://192.168.1.3:5678
```

From outside the LAN, keep Tailscale connected and use the same LAN URL
`http://192.168.1.3:8123`; access is provided by the approved subnet route.

## Updating Later

For normal updates on the server, update flake inputs, commit the lock file, then
rebuild. The hosted containers are configured to restart when `flake.lock`
changes and to pull the current registry image for their configured tags:

```sh
cd /home/joshan/.files &&
  git pull --recurse-submodules &&
  nix flake update &&
  git add flake.lock &&
  git commit -m "chore: update flake inputs" &&
  sudo nixos-rebuild switch --flake .#nixos-server
```

For app config changes managed outside Nix, container app data lives under:

```text
/var/lib/apps/<app-name>
```

Those paths are covered by Snapper snapshots and the restic Dropbox backup.

The external Vault pool is restored separately after a full system-disk rebuild.
Follow [Vault ZFS Storage](vault-storage.md) to import and verify it; do not run
the destructive pool-creation step again. Vault data is locally snapshotted but
is not included in the app-data restic backup. Then restore the PostgreSQL-backed
application databases using
[Backup And Restore](backup-restore.md#postgresql-application-databases).
