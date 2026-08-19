# Native Immich

Immich runs as the native NixOS `services.immich` service on the Raspberry Pi.
It is not containerized.

## Storage layout

The deployment keeps database state and large media on the server's two
existing storage tiers:

| Path | Purpose | Protection |
| --- | --- | --- |
| `/var/lib/apps/postgresql/<schema>` | Live PostgreSQL cluster, including the Immich database | Local Snapper snapshots; excluded from restic while PostgreSQL is running |
| `/var/lib/apps/immich/database-backups/immich.sql.gz` | Native NixOS logical dump of the Immich database | Snapper plus restic/Dropbox |
| `/srv/vault/photos/immich` | Media managed by Immich, including Immich's own automatic database backups | Vault ZFS/Sanoid snapshots only |
| `/srv/vault/media-library` | Existing phone photo/video library exposed to Immich as an external library | Vault ZFS/Sanoid snapshots only |

The existing media library is not copied into Immich. The native
`immich-server` unit receives the shared Vault group only for access and bind
mounts `/srv/vault/media-library` read-only inside its private mount namespace.
Immich therefore indexes the existing files without being able to modify them.
Managed uploads, thumbnails, encoded video, profiles, and Immich's own database
backups stay under `/srv/vault/photos/immich`.

The native Immich module uses local Unix sockets for PostgreSQL and Redis, so no
database password is required in Nix. If a future Immich setting needs a secret,
keep it under `dotfiles.server.secretsDir` (`/root/secrets`) and reference it
through the native module's secret-file support; never place secret values
inline in Nix.

## Deployment

Before switching, confirm the existing phone library is present:

```sh
findmnt /srv/vault
test -d /srv/vault/media-library
find /srv/vault/media-library -maxdepth 2 -type f | head
```

Then evaluate and deploy the native service:

```sh
cd /home/joshan/.files

nix eval .#nixosConfigurations.nixos-server.config.services.immich.enable
nix eval --raw .#nixosConfigurations.nixos-server.config.services.immich.mediaLocation
nix eval --raw .#nixosConfigurations.nixos-server.config.services.postgresql.dataDir
nix eval --raw .#nixosConfigurations.nixos-server.config.services.postgresqlBackup.location

sudo nixos-rebuild dry-activate --flake .#nixos-server
sudo nixos-rebuild switch --flake .#nixos-server
```

Expected values are `true`, `/srv/vault/photos/immich`, a PostgreSQL data
directory below `/var/lib/apps/postgresql`, and
`/var/lib/apps/immich/database-backups`.

The `immich-vault-storage` oneshot deliberately fails if
`/srv/vault/media-library` is missing. It also requires `/srv/vault` to be a
mounted filesystem before it creates `/srv/vault/photos/immich`, preventing a
missing Vault pool from silently redirecting media onto the SD card.

## First-run checks

Verify all native units and storage paths before importing anything:

```sh
systemctl status \
  immich-vault-storage.service \
  immich-server.service \
  postgresql.service \
  redis-immich.service \
  --no-pager

findmnt /srv/vault
stat -c '%A %U %G %n' \
  /srv/vault \
  /srv/vault/photos \
  /srv/vault/photos/immich \
  /srv/vault/media-library

sudo -u immich find /srv/vault/media-library -type f -readable -print -quit
systemctl show immich-server.service -p BindReadOnlyPaths -p SupplementaryGroups
ss -ltnp | grep ':2283'
```

The `find` command must print a file, and `BindReadOnlyPaths` must include
`/srv/vault/media-library`. If the read check fails, fix the existing library's
group/read permissions rather than making the managed Immich media directory
point at the source library.

## Add the existing phone library

Open the Immich web UI, create the first administrator account if needed, then
add an external library whose import path is:

```text
/srv/vault/media-library
```

External-library membership is application database state, so it is configured
inside Immich rather than hard-coded into the NixOS service module. After adding
it, start a library scan and confirm that photos and videos appear without
moving or duplicating the source files.

## LAN and Tailscale access

Immich listens on all host interfaces on TCP port `2283`, and the NixOS firewall
opens that port. On the home LAN use:

```text
http://192.168.1.3:2283
```

The server is already a Tailscale subnet router for `192.168.1.0/24`, so remote
Tailnet clients can use the same stable LAN URL through the advertised subnet
route. Validate from at least one LAN client and one Tailnet client before
relying on remote access.

## Raspberry Pi performance expectations

The Raspberry Pi 4 has limited CPU and memory for Immich's heavier background
work. The initial deployment therefore disables `services.immich.machine-learning`.
This avoids face recognition and semantic-search model loading while the basic
photo library is being evaluated.

Thumbnail generation, metadata extraction, RAW decoding, and video transcoding
still run on the Pi and can be CPU-intensive. For the pilot library, watch the
native service and system load while the first scan runs:

```sh
journalctl -fu immich-server.service
systemd-cgtop
free -h
uptime
```

Do not judge steady-state responsiveness from the first scan alone. Record how
long the initial thumbnail/metadata jobs take, whether interactive UI latency is
acceptable during that work, and whether the Pi begins swapping or throttling.
Only enable machine learning after the base workload is acceptable. If ML is
wanted later, a separate faster machine-learning endpoint is preferable to
loading large models on the Pi itself.

## Snapshot and backup validation

The live PostgreSQL cluster remains under `/var/lib/apps`, so local Snapper
snapshots cover it. Restic deliberately excludes `/var/lib/apps/postgresql`
because copying a running PostgreSQL data directory is not the offsite restore
mechanism. Instead, the native `services.postgresqlBackup` timer creates a
consistent logical dump at
`/var/lib/apps/immich/database-backups/immich.sql.gz`; the existing app-data
restic job then carries that dump offsite.

Immich also creates its own automatic database backups under
`/srv/vault/photos/immich/backups`. Those are useful for Immich's built-in
restore flow but remain Vault-local unless a future offsite policy adds them.
Bulk photos and videos stay below `/srv/vault`, outside the Dropbox/restic path,
and follow the recursive Sanoid policy for `vault/data`.

Validate both sides after deployment:

```sh
sudo systemctl start postgresqlBackup-immich.service
systemctl status postgresqlBackup-immich.service --no-pager
ls -lh /var/lib/apps/immich/database-backups/immich.sql.gz

sudo snapper -c apps list
sudo systemctl status restic-backups-apps.timer --no-pager || true

zfs list -t snapshot -r vault/data
systemctl status sanoid.timer --no-pager

nix eval --json \
  .#nixosConfigurations.nixos-server.config.services.restic.backups.apps.paths
nix eval --json \
  .#nixosConfigurations.nixos-server.config.services.restic.backups.apps.exclude
```

The restic paths must contain `/var/lib/apps` and must not contain `/srv/vault`.
The exclusion list must contain `/var/lib/apps/postgresql`. Create or wait for a
fresh ZFS snapshot after the Immich media tree exists, then confirm the snapshot
contains `photos/immich` and `media-library`.

## Restore expectations

Treat the database and media as one logical application even though they use two
storage systems. A useful restore needs a compatible database backup and the
corresponding Vault media tree.

For a small accidental media deletion, restore the affected file from a Vault
snapshot using the copy-first process in `backup-restore.md`.

For an Immich database problem, prefer a logical backup over copying the live
PostgreSQL data directory. Immich's automatic backups under
`/srv/vault/photos/immich/backups` can be restored through Immich's maintenance
or onboarding UI. The offsite NixOS dump is the fallback when that copy is not
available. To restore the NixOS dump into the existing `immich` database, stop
Immich first and restore the SQL transactionally:

```sh
sudo systemctl stop immich-server.service

sudo -u postgres gzip -dc \
  /var/lib/apps/immich/database-backups/immich.sql.gz \
  | sudo -u postgres psql \
      --dbname=immich \
      --single-transaction \
      --set ON_ERROR_STOP=on

sudo systemctl start immich-server.service
```

Use a dump from a compatible Immich version when possible. After restoring,
check the server journal for migrations and verify assets before allowing new
uploads.

For a full server rebuild:

1. Import the existing `vault` pool; do not recreate it.
2. Restore `/var/lib/apps/immich/database-backups` from restic if the SD-card state was lost.
3. Apply the NixOS configuration so PostgreSQL, Redis, and Immich are recreated.
4. Verify `/srv/vault/photos/immich` and `/srv/vault/media-library`.
5. Prefer Immich's built-in restore from the Vault backup directory; use the offsite logical dump if needed.
6. Verify the external library and managed media before allowing new uploads.

Because `/srv/vault` has local snapshots but no offsite copy, loss of both Vault
drives can still lose the photo/video library even when an Immich database dump
survives in Dropbox. Do not treat the current Immich deployment as the only copy
of irreplaceable media until a separate offsite policy exists.
