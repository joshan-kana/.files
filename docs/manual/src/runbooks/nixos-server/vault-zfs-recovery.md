# Vault / ZFS recovery

Vault is the server's bulk local-data layer. Pool creation is deliberately an explicit human action because it destroys existing disk contents; normal NixOS activation only manages the configuration around an existing pool.

Current filesystem, Vault, pool, snapshot, and retention state is in [Storage](../../infrastructure/storage.md).

Load the generated server environment once in the shell used for the recovery procedure:

```sh
{{#include ../../generated/server-env.sh}}
```

## Physical setup and safety

Use stable whole-disk `/dev/disk/by-id/...` paths for pool creation. Do not substitute `/dev/sdX` names, which can change across boots or reconnections.

Before any destructive setup action:

```sh
lsusb
lsblk -o NAME,PATH,SIZE,FSTYPE,FSVER,LABEL,MODEL,SERIAL,TRAN,MOUNTPOINTS
find /dev/disk/by-id -maxdepth 1 -type l -printf '%f -> %l\n' \
  | sort \
  | grep -Ei 'lacie|seagate|usb|ata'
```

The repository setup script performs additional safety checks, evaluates the current server configuration for the pool name/mount/group, refuses mounted devices and existing/importable ZFS members, and requires an explicit confirmation before applying changes.

## First-time pool creation

Build and switch the storage configuration first. Then run the setup script in dry-run mode with the two unambiguous whole-disk IDs:

```sh
cd "$DOTFILES_REPO"

sudo ./scripts/nixos-server/create-vault-zfs.sh \
  --dry-run \
  /dev/disk/by-id/DISK_A \
  /dev/disk/by-id/DISK_B
```

Review the detected devices, signatures, and exact ZFS commands. Apply only when they match the intended disks:

```sh
sudo ./scripts/nixos-server/create-vault-zfs.sh \
  --apply \
  /dev/disk/by-id/DISK_A \
  /dev/disk/by-id/DISK_B
```

Verify the resulting pool and mount using the evaluated names:

```sh
zpool status "$VAULT_POOL"
zfs list -r "$VAULT_POOL"
findmnt "$VAULT_ROOT"
zfs get mounted,mountpoint,compression,atime,recordsize -r "$VAULT_POOL"
systemctl list-timers --all | grep -E 'sanoid|zfs-scrub|snapper'
```

Do not rerun the creation script as a recovery mechanism for an existing pool.

## Incomplete media downloads

`vault/data` is snapshotted by Sanoid. Transmission's incomplete torrent files live on
`vault/downloads-incomplete`, a sibling dataset mounted at
`/srv/vault/media/downloads/incomplete`. That dataset is intentionally absent from
Sanoid's snapshot targets. Completed downloads remain on `vault/data` beside the
Sonarr/Radarr library, preserving hardlinked imports.

The dataset is created once, outside NixOS activation. For an existing server,
prepare it **before switching to the NixOS generation containing its filesystem
mount**. Pause downloading, preserve the original incomplete data, and copy it
onto the new dataset before restarting Transmission:

```sh
sudo systemctl stop transmission.service
sudo systemctl stop sanoid.timer
sudo mv /srv/vault/media/downloads/incomplete /srv/vault/media/downloads/incomplete-before-zfs
sudo install -d -m 2770 -o transmission -g server-data /srv/vault/media/downloads/incomplete
sudo zfs create -o mountpoint=legacy vault/downloads-incomplete
sudo mount -t zfs vault/downloads-incomplete /srv/vault/media/downloads/incomplete
sudo rsync -aHEX --sparse /srv/vault/media/downloads/incomplete-before-zfs/ /srv/vault/media/downloads/incomplete/
sudo chown transmission:server-data /srv/vault/media/downloads/incomplete
sudo chmod 2770 /srv/vault/media/downloads/incomplete
```

Confirm the mount is actually backed by `vault/downloads-incomplete`, then switch
the NixOS configuration and start the services:

```sh
findmnt /srv/vault/media/downloads/incomplete
sudo systemctl start transmission.service sanoid.timer
zfs list -r vault
zfs list -t snapshot -r vault
```

Confirm existing incomplete torrents resume and completed imports retain hardlinks.
Keep the `incomplete-before-zfs` directory until all resumed torrents are verified;
remove it only after verifying the data has been copied successfully. Its blocks
may continue to be referenced by earlier snapshots until normal retention prunes
them. Because incomplete and completed files now occupy different datasets,
Transmission must copy, rather than rename, a file on completion. This adds I/O
but leaves completed torrents and the media library on the same filesystem.

## Routine health checks

```sh
zpool status -x "$VAULT_POOL"
zpool status "$VAULT_POOL"
zfs list -r "$VAULT_POOL"
zfs list -t snapshot -r "$VAULT_POOL"
findmnt "$VAULT_ROOT"
systemctl status sanoid.timer zfs-scrub.timer --no-pager
systemctl list-timers --all | grep -E 'sanoid|zfs-scrub|snapper'
journalctl -u sanoid.service -u zfs-scrub.service --since '7 days ago'
```

Snapshot interval and retention policy are shown in [Storage](../../infrastructure/storage.md). Change them in Nix rather than editing this runbook.

## Recover a file or directory from a snapshot

List snapshots oldest to newest:

```sh
zfs list \
  -t snapshot \
  -r "$VAULT_DATASET" \
  -s creation \
  -o name,creation,used,refer
```

Browse a snapshot through the read-only `.zfs/snapshot` view:

```sh
snapshot=<snapshot-name-after-@>
ls -la "$VAULT_ROOT/.zfs/snapshot/$snapshot"
```

Copy a single file or directory to a temporary recovery location before replacing live state:

```sh
snapshot=<snapshot-name-after-@>
relative_path=<path-relative-to-vault-root>
recovery_path=/tmp/vault-recovery

sudo mkdir -p "$recovery_path"
sudo cp -a \
  "$VAULT_ROOT/.zfs/snapshot/$snapshot/$relative_path" \
  "$recovery_path/"
```

For a larger restore, preview the changes with `rsync` first:

```sh
snapshot=<snapshot-name-after-@>
sudo rsync -aHAXn --delete \
  "$VAULT_ROOT/.zfs/snapshot/$snapshot/" \
  "$VAULT_ROOT/"
```

Remove `-n` only after reviewing the dry run. `--delete` removes live files that did not exist in the selected snapshot.

## Inspect through a temporary clone

A clone is useful when the old state must be inspected without touching the live dataset:

```sh
snapshot=<snapshot-name-after-@>

sudo zfs clone \
  -o mountpoint=/mnt/vault-recovery \
  "$VAULT_DATASET@$snapshot" \
  "$VAULT_POOL/recovery"

findmnt /mnt/vault-recovery
```

After copying out the required data:

```sh
sudo zfs destroy "$VAULT_POOL/recovery"
```

## Whole-dataset rollback

Whole-dataset rollback is a last resort because it discards live changes and `-r` destroys snapshots newer than the selected point.

Stop every service that writes to Vault and preserve any current state that must survive. Then, only when a full rollback is explicitly intended:

```sh
snapshot=<snapshot-name-after-@>
sudo zfs rollback -r "$VAULT_DATASET@$snapshot"
```

Prefer file copies or a temporary clone whenever they can solve the problem.

## Full server rebuild and pool import

After rebuilding the internal system disk, reconnect the existing Vault drives only after the base NixOS system is healthy. In the rebuilt system's shell, reload the generated environment before applying the current configuration and inspecting/importing the existing pool:

```sh
{{#include ../../generated/server-env.sh}}
```

```sh
cd "$DOTFILES_REPO"
sudo nixos-rebuild switch --flake ".#nixos-server"

sudo zpool import
sudo zpool import "$VAULT_POOL"

zpool status "$VAULT_POOL"
zfs list -r "$VAULT_POOL"
findmnt "$VAULT_ROOT"
```

If the pool is already imported, `zpool import "$VAULT_POOL"` will not find it in the importable list. Verify with `zpool status "$VAULT_POOL"` instead.

If import fails, inspect without forcing anything:

```sh
lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MODEL,SERIAL,TRAN,MOUNTPOINTS
sudo zpool import -d /dev/disk/by-id
sudo zpool import -d /dev/disk/by-id "$VAULT_POOL"
journalctl -b -u "zfs-import-$VAULT_POOL.service" --no-pager
```

Check power, cables, and stable device IDs before considering `zpool import -f`. Never recreate or wipe the pool as an import-recovery step.
