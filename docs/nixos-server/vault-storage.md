# Vault ZFS Storage

Vault is the server's local bulk-data layer: two USB HDDs in a ZFS mirror mounted
at `/srv/vault`. The Nix configuration is the source of truth for pool settings,
scrub cadence, snapshot cadence, and retention; this document only keeps the
stable setup and recovery steps.

## Storage model

| Path | Storage | Protection |
| --- | --- | --- |
| `/var/lib/apps` | Btrfs on the SD card | Snapper + restic |
| `/srv/vault` | ZFS mirror | ZFS checksums/self-healing + Sanoid snapshots |

Applications own their directories below `/srv/vault`; keep app-specific layout
and recovery details in the corresponding app runbook.

## One-time pool creation

Pool creation is destructive and must only be done once. Use stable
`/dev/disk/by-id/...` whole-disk paths, never `/dev/sdX`.

```sh
find /dev/disk/by-id -maxdepth 1 -type l -printf '%f -> %l\n' | sort

sudo ./scripts/nixos-server/create-vault-zfs.sh \
  --dry-run \
  /dev/disk/by-id/DISK_A \
  /dev/disk/by-id/DISK_B

sudo ./scripts/nixos-server/create-vault-zfs.sh \
  --apply \
  /dev/disk/by-id/DISK_A \
  /dev/disk/by-id/DISK_B

zpool status vault
findmnt /srv/vault
```

The script performs the safety checks and derives the intended pool name,
mountpoint, and collaboration group from the Nix configuration. Do not rerun it
to recover an existing pool.

## Protection and health

ZFS checksums every block. The mirror lets ZFS repair a bad copy from the healthy
disk, and the configured scrub regularly reads allocated data to discover latent
corruption. Sanoid provides point-in-time recovery from deletion or unwanted
changes.

Routine checks:

```sh
zpool status -x vault
zpool status vault
zfs list -r vault
zfs list -t snapshot -r vault
findmnt /srv/vault
systemctl status sanoid.timer zfs-scrub.timer --no-pager
```

A healthy pool should report no known data errors. Investigate any
`DEGRADED`, `FAULTED`, checksum errors, or permanent errors before replacing or
rewriting data.

## Rebuild or import recovery

After rebuilding the server, keep both Vault drives attached. If the pool is not
imported automatically, inspect and import the existing pool:

```sh
sudo zpool import
sudo zpool import -d /dev/disk/by-id vault

zpool status vault
findmnt /srv/vault
```

If import fails, inspect device IDs, cables, power, and pool status first. Do not
recreate, format, or wipe the pool as a recovery step.
