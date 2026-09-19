# Vault ZFS Storage

Vault is the server's large local-data layer. Two backed-up 2 TB
LaCie USB HDDs form a ZFS mirror named `vault`, with about 2 TB usable capacity
and continued availability after one drive fails.

The storage layers deliberately remain separate:

| Path | Storage | Protection |
| --- | --- | --- |
| `/var/lib/apps` | Btrfs on the internal NVMe | Local Snapper snapshots and offsite restic/Dropbox backups |
| `/srv/vault` | Mirrored LaCie USB HDDs | Local recursive Sanoid/ZFS snapshots only |

`/srv/vault` is not included in the restic/Dropbox backup in this change.
Mirroring and snapshots are not offsite backups.

## Physical Setup And Safety

Connect both drives to USB 3.x ports with the verified USB 3.0 cables. Pool creation is a one-time, explicit operation because it erases both
drives. Normal NixOS activation only enables ZFS import, scrubs, and snapshots;
it never wipes disks or creates the pool.

The setup script accepts only whole-disk `/dev/disk/by-id/...` paths, refuses
mounted devices, shows signatures and exact commands in dry-run mode, and
requires `CREATE VAULT` to apply. Never substitute `/dev/sda` or `/dev/sdb`.

## First-Time Setup

Run this after the storage configuration has been built and switched. Replace
`DISK_A` and `DISK_B` with the two unambiguous LaCie whole-disk IDs. The dry run
should show two roughly 2 TB USB disks, expected NTFS signatures, and no mounts.

The setup script evaluates the effective `nixos-server` configuration before
making changes. Its pool name, dataset mountpoint, and collaboration group come
from:

- `dotfiles.server.storage.dataRoot.poolName`
- `dotfiles.server.storage.dataRoot.path`
- `dotfiles.server.storage.dataRoot.group.name`

Do not duplicate those values inside the script. Change them in Nix and rebuild
the server before running first-time setup. The script refuses to overwrite an
imported or importable pool and rejects disks containing ZFS member metadata.

```bash
cd /home/joshan/.files

lsusb
lsblk -o NAME,PATH,SIZE,FSTYPE,FSVER,LABEL,MODEL,SERIAL,TRAN,MOUNTPOINTS
find /dev/disk/by-id -maxdepth 1 -type l -printf '%f -> %l\n' \
  | sort \
  | grep -Ei 'lacie|seagate|usb|ata'

sudo ./scripts/nixos-server/create-vault-zfs.sh \
  --dry-run \
  /dev/disk/by-id/DISK_A \
  /dev/disk/by-id/DISK_B

sudo ./scripts/nixos-server/create-vault-zfs.sh \
  --apply \
  /dev/disk/by-id/DISK_A \
  /dev/disk/by-id/DISK_B

zpool status vault
zfs list -r vault
findmnt /srv/vault
zfs get mounted,mountpoint,compression,atime,recordsize -r vault
systemctl list-timers --all | grep -E 'sanoid|zfs-scrub|snapper'
sudo snapper list-configs || true
sudo snapper -c apps list || true
```

The initial dataset layout is:

```text
vault/data                 /srv/vault
```

Child datasets and working directories are added alongside the applications
that consume them instead of being created speculatively. Servers provisioned
with an earlier version of the script may retain the previous empty child
datasets until they are explicitly removed.

Immich uses `/srv/vault/immich` as its managed media root and indexes the
existing `/srv/vault/media-library` in place as an external library. Its logical
database dumps live under `/srv/vault/immich/backups`, where Vault snapshots
and the apps restic backup protect them. See [Native Immich](immich.md) for
deployment and first-run setup.

Paperless uses `/srv/vault/paperless` for its document media and consume
directory. Its application data and PostgreSQL dumps stay under
`/var/lib/apps/paperless` for Snapper + restic protection. See
[Paperless-ngx](paperless.md) for first-run and recovery notes.

## Routine Health Checks

```bash
zpool status -x vault
zpool status vault
zfs list -r vault
zfs list -t snapshot -r vault
findmnt /srv/vault

systemctl status sanoid.timer zfs-scrub.timer --no-pager
systemctl list-timers --all | grep -E 'sanoid|zfs-scrub|snapper'
journalctl -u sanoid.service -u zfs-scrub.service --since '7 days ago'
```

Sanoid checks `vault/data` and all child datasets every 15 minutes, retaining
four frequent snapshots plus 48 hourly, 14 daily, 8 weekly, and 12 monthly
snapshots. The shared interval and retention settings also protect
`/var/lib/apps` through Snapper, while restic uses the shared retention settings
for offsite pruning.

## Full Rebuild And Pool Import

After rebuilding the server NVMe, reconnect the LaCie drives. Apply the NixOS
configuration, inspect importable pools, then import Vault if it was not imported
automatically. Do not run the pool-creation script again.

```bash
cd /home/joshan/.files
sudo nixos-rebuild switch --flake .#nixos-server

sudo zpool import
sudo zpool import vault

zpool status vault
zfs list -r vault
findmnt /srv/vault

sudo nixos-rebuild switch --flake .#nixos-server

zpool status vault
zfs list -r vault
systemctl list-timers --all | grep -E 'sanoid|zfs-scrub|snapper'
```

If `vault` is already imported, `sudo zpool import vault` will report that no
such pool is available; verify it with `zpool status vault`. If import fails,
inspect without forcing anything:

```bash
lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MODEL,SERIAL,TRAN,MOUNTPOINTS
sudo zpool import -d /dev/disk/by-id
sudo zpool import -d /dev/disk/by-id vault
journalctl -b -u zfs-import-vault.service --no-pager
```

Check cables, power, and the stable device IDs before considering `zpool import
-f`. Never recreate or wipe the pool as an import-recovery step.
