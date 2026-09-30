# Vault ZFS storage

Vault is the server's bulk local-data layer. Pool creation is deliberately an explicit human action because it destroys existing disk contents; normal NixOS activation only manages the configuration around an existing pool.

## Current evaluated storage configuration

{{#include ../generated/storage-reference.md}}

The command examples use these generated values:

```sh
{{#include ../generated/server-env.sh}}
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
{{#include ../generated/server-env.sh}}
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
{{#include ../generated/server-env.sh}}
zpool status "$VAULT_POOL"
zfs list -r "$VAULT_POOL"
findmnt "$VAULT_ROOT"
zfs get mounted,mountpoint,compression,atime,recordsize -r "$VAULT_POOL"
systemctl list-timers --all | grep -E 'sanoid|zfs-scrub|snapper'
```

Do not rerun the creation script as a recovery mechanism for an existing pool.

## Routine health checks

```sh
{{#include ../generated/server-env.sh}}
zpool status -x "$VAULT_POOL"
zpool status "$VAULT_POOL"
zfs list -r "$VAULT_POOL"
zfs list -t snapshot -r "$VAULT_POOL"
findmnt "$VAULT_ROOT"
systemctl status sanoid.timer zfs-scrub.timer --no-pager
systemctl list-timers --all | grep -E 'sanoid|zfs-scrub|snapper'
journalctl -u sanoid.service -u zfs-scrub.service --since '7 days ago'
```

Snapshot interval and retention policy are generated at the top of this page from the current configuration. Change them in Nix rather than editing this runbook.

## Recover a file or directory from a snapshot

List snapshots oldest to newest:

```sh
{{#include ../generated/server-env.sh}}
zfs list \
  -t snapshot \
  -r "$VAULT_DATASET" \
  -s creation \
  -o name,creation,used,refer
```

Browse a snapshot through the read-only `.zfs/snapshot` view:

```sh
{{#include ../generated/server-env.sh}}
snapshot=<snapshot-name-after-@>
ls -la "$VAULT_ROOT/.zfs/snapshot/$snapshot"
```

Copy a single file or directory to a temporary recovery location before replacing live state:

```sh
{{#include ../generated/server-env.sh}}
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
{{#include ../generated/server-env.sh}}
snapshot=<snapshot-name-after-@>
sudo rsync -aHAXn --delete \
  "$VAULT_ROOT/.zfs/snapshot/$snapshot/" \
  "$VAULT_ROOT/"
```

Remove `-n` only after reviewing the dry run. `--delete` removes live files that did not exist in the selected snapshot.

## Inspect through a temporary clone

A clone is useful when the old state must be inspected without touching the live dataset:

```sh
{{#include ../generated/server-env.sh}}
snapshot=<snapshot-name-after-@>

sudo zfs clone \
  -o mountpoint=/mnt/vault-recovery \
  "$VAULT_DATASET@$snapshot" \
  "$VAULT_POOL/recovery"

findmnt /mnt/vault-recovery
```

After copying out the required data:

```sh
{{#include ../generated/server-env.sh}}
sudo zfs destroy "$VAULT_POOL/recovery"
```

## Whole-dataset rollback

Whole-dataset rollback is a last resort because it discards live changes and `-r` destroys snapshots newer than the selected point.

Stop every service that writes to Vault and preserve any current state that must survive. Then, only when a full rollback is explicitly intended:

```sh
{{#include ../generated/server-env.sh}}
snapshot=<snapshot-name-after-@>
sudo zfs rollback -r "$VAULT_DATASET@$snapshot"
```

Prefer file copies or a temporary clone whenever they can solve the problem.

## Full server rebuild and pool import

After rebuilding the internal system disk, reconnect the existing Vault drives only after the base NixOS system is healthy. Apply the current configuration, inspect importable pools, and import the existing pool if it was not imported automatically:

```sh
{{#include ../generated/server-env.sh}}
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
{{#include ../generated/server-env.sh}}
lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MODEL,SERIAL,TRAN,MOUNTPOINTS
sudo zpool import -d /dev/disk/by-id
sudo zpool import -d /dev/disk/by-id "$VAULT_POOL"
journalctl -b -u "zfs-import-$VAULT_POOL.service" --no-pager
```

Check power, cables, and stable device IDs before considering `zpool import -f`. Never recreate or wipe the pool as an import-recovery step.
