# Backup And Restore

## What Nix Manages

NixOS manages the normal backup/rollback machinery:

- `services.snapper`: creates local `/var/lib/apps` snapshots every 15 minutes.
- `services.restic.backups.apps`: backs up app data to Dropbox every
  30 minutes.
- `virtualisation.oci-containers` and native services: run the hosted apps with
  explicit persistent storage.

You should not normally run backup commands by hand. The manual commands below
are for setup checks, “did it work?” verification, and emergency restore.

## Restore Order

Use the least destructive option that solves the problem:

1. Identify whether the affected path is under `/var/lib/apps` or `/srv/vault`.
2. Stop the service or container that writes to it.
3. List the available snapshots and inspect the intended snapshot.
4. Copy the affected files to a temporary location and compare them.
5. Restore only the affected files or directory.
6. Start the service and verify it.

Do not begin with `snapper undochange`, `rsync --delete`, `zfs rollback`, or
`zfs destroy`. Those commands can replace or delete current state. The sections
below put preview and copy-based recovery before whole-filesystem rollback.

## Two Different Rollbacks

There are two kinds of state:

| Thing | Where it lives | How to roll back |
| --- | --- | --- |
| NixOS config | Git repo | Check out an older commit and rebuild |
| App data | `/var/lib/apps` | Restore a Snapper snapshot or restic backup, subject to the exclusions below |
| Large Vault data | `/srv/vault` | Restore a local ZFS snapshot or import the existing mirrored pool |

That split is intentional. If an app edit breaks something, restore app data
without rolling back the whole NixOS system.

## App Data Locations

Application state lives under one parent directory:

```text
/var/lib/apps
```

Current child paths include:

```text
/var/lib/apps/home-assistant
/var/lib/apps/adguard
/var/lib/apps/matter-server
/var/lib/apps/n8n
/var/lib/apps/openclaw
/var/lib/apps/openclaw-auth
/var/lib/apps/postgresql
/var/lib/apps/immich/database-backups
```

Future apps should store mutable state under `/var/lib/apps` where practical so
local Snapper protection remains consistent. Offsite restic coverage can differ
for state that needs an application-aware backup method; the live PostgreSQL
cluster is the current example.

Large files stored under `/srv/vault` use local recursive ZFS snapshots and are
not included in this restic repository. See [Vault ZFS Storage](vault-storage.md)
for health checks, snapshot verification, and full-rebuild import instructions.
See [Native Immich](immich.md) for the split between Immich's live PostgreSQL
cluster, logical database dumps, managed Vault media, and external library.

Tailscale is a native service and uses its own state outside `/var/lib/apps`.
Normal replacement installs enrol with `/root/secrets/tailscale-oauth-client-secret` instead
of restoring an old Tailscale machine identity.

## Restic Repository

The offsite restic repository is stored through the `dropbox` rclone remote at:

```text
Archives/Backups/nixos-server
```

The full repository URI used by NixOS is:

```text
rclone:dropbox:Archives/Backups/nixos-server
```

## What About Secrets?

Secrets are split into two buckets:

| Secret | Where it lives | Backed up how |
| --- | --- | --- |
| Home Assistant `secrets.yaml` | `/var/lib/apps/home-assistant/secrets.yaml` | Snapper and restic |
| AdGuard admin hash/config secrets | `/var/lib/apps/adguard/conf` | Snapper and restic |
| n8n credentials database | `/var/lib/apps/n8n` | Snapper and restic |
| n8n runtime secrets | `/root/secrets/n8n.env` | Separate encrypted copy |
| OpenClaw app config/passwords | `/var/lib/apps/openclaw` | Snapper and restic |
| OpenClaw auth profile secrets | `/var/lib/apps/openclaw-auth` | Snapper and restic |
| OpenClaw env passwords/tokens | `/root/secrets/openclaw.env` | Separate encrypted copy |
| Tailscale first-boot auth key | `/root/secrets/tailscale-oauth-client-secret` | Separate encrypted copy |
| Dropbox/rclone config | `/root/secrets/rclone.conf` | Separate encrypted copy |
| Restic repository password | `/root/secrets/restic-password` | Separate encrypted copy |

The `/root/secrets` files are the keys needed before restic can restore
anything. Keep copies in a password manager, `sops-nix`, or an encrypted archive
whose password is stored somewhere you can reach after the Pi dies.

## Fast Local App-Data Restore

Use this when a bad app config change needs to be rolled back quickly from a
local Snapper snapshot.

List snapshots:

```sh
sudo snapper -c apps list
```

Preview the changes between two snapshots:

```sh
sudo snapper -c apps status <old>..<new>
```

Restore one app directory. Stop the affected app first, restore its app-data
directory, then start it again. This example restores n8n:

```sh
sudo systemctl stop docker-n8n.service
sudo snapper -c apps undochange <old>..<new> /var/lib/apps/n8n
sudo systemctl start docker-n8n.service
```

Restore the whole hosted app-data directory. Stop affected containers first,
restore `/var/lib/apps`, then switch the NixOS profile so systemd reconciles the
container units:

```sh
sudo snapper -c apps undochange <old>..<new> /var/lib/apps
sudo nixos-rebuild switch --flake /home/joshan/.files#nixos-server
```

`<old>..<new>` is the snapshot range Snapper shows from `snapper list`.

Use the single-app restore when only one app is broken. Use the whole
`/var/lib/apps` restore when the full hosted app state needs to go back to the
same point in time. For PostgreSQL-backed apps, prefer the documented logical
backup/restore flow unless you specifically need a local crash-consistent
filesystem snapshot recovery.

## Vault ZFS Snapshot Restore

Use ZFS snapshots for data under `/srv/vault`. These snapshots are local to the
Vault mirror: they protect against accidental changes and deletions, but not the
loss of both drives.

Choose the operation by scope:

| Situation | Use |
| --- | --- |
| One deleted or damaged file | Copy it from `.zfs/snapshot` |
| Several files or a directory | Preview and apply an `rsync` restore |
| Unsure what the old state contains | Create a temporary ZFS clone |
| Entire dataset must return to an earlier state | `zfs rollback` as a last resort |

List snapshots from oldest to newest:

```sh
zfs list \
  -t snapshot \
  -r vault/data \
  -s creation \
  -o name,creation,used,refer
```

Snapshot names look like:

```text
vault/data@autosnap_2026-07-19_16:35:41_frequently
```

The part after `@` is available as a read-only directory under
`.zfs/snapshot`. Browse a snapshot without changing the live data:

```sh
snapshot='autosnap_2026-07-19_16:35:41_frequently'

ls -la "/srv/vault/.zfs/snapshot/$snapshot"
```

Restore one file or directory by copying it from the snapshot. Copy it to a
temporary path first when the live version still exists, so it can be compared
before replacement:

```sh
snapshot='autosnap_2026-07-19_16:35:41_frequently'
relative_path='path/to/file-or-directory'
recovery_path='/tmp/vault-recovery'

sudo mkdir -p "$recovery_path"
sudo cp -a \
  "/srv/vault/.zfs/snapshot/$snapshot/$relative_path" \
  "$recovery_path/"
```

For a larger restore, preview the changes with `rsync` before applying them:

```sh
snapshot='autosnap_2026-07-19_16:35:41_frequently'

sudo rsync -aHAXn --delete \
  "/srv/vault/.zfs/snapshot/$snapshot/" \
  /srv/vault/
```

Remove `-n` only after reviewing the dry-run output. Be especially careful
with `--delete`: it makes the live dataset match the snapshot by deleting files
that did not exist at that time.

To inspect a snapshot as an independent writable dataset, clone it temporarily:

```sh
snapshot='autosnap_2026-07-19_16:35:41_frequently'

sudo zfs clone \
  -o mountpoint=/mnt/vault-recovery \
  "vault/data@$snapshot" \
  vault/recovery

findmnt /mnt/vault-recovery
```

After copying out anything needed, remove the temporary clone:

```sh
sudo zfs destroy vault/recovery
```

If future child datasets exist, each child has its own snapshot and must be
restored or cloned separately.

Whole-dataset rollback is a last resort:

```sh
sudo zfs rollback -r \
  vault/data@autosnap_2026-07-19_16:35:41_frequently
```

Before running it, stop every service that writes to the dataset and preserve
the current state somewhere outside `vault/data`. The `-r` flag permanently
destroys every snapshot newer than the selected snapshot, and the rollback
discards all live changes made since that snapshot. Prefer copying individual
files or using a temporary clone whenever possible.

## Offsite Restore From Dropbox

Use this if the local disk is lost or the local snapshots are not enough.

List encrypted backup points:

```sh
sudo env RCLONE_CONFIG=/root/secrets/rclone.conf \
  restic -r rclone:dropbox:Archives/Backups/nixos-server \
  --password-file /root/secrets/restic-password snapshots
```

Restore all app data on a replacement server:

```sh
sudo env RCLONE_CONFIG=/root/secrets/rclone.conf \
  restic -r rclone:dropbox:Archives/Backups/nixos-server \
  --password-file /root/secrets/restic-password restore latest \
  --target / \
  --include /var/lib/apps
```

Restore one app if only that app is broken:

```sh
sudo env RCLONE_CONFIG=/root/secrets/rclone.conf \
  restic -r rclone:dropbox:Archives/Backups/nixos-server \
  --password-file /root/secrets/restic-password restore latest \
  --target / \
  --include /var/lib/apps/n8n
```

The restored `/var/lib/apps` tree will not contain the live PostgreSQL cluster,
because that path is intentionally excluded from restic. Restore PostgreSQL
applications from their logical dumps instead; for Immich, use
`/var/lib/apps/immich/database-backups/immich.sql.gz` as described in
[Native Immich](immich.md).

## Restic Exclusions

The current default restic exclusions are:

```text
/var/lib/apps/home-assistant/www/media/ha-bambulab
/var/lib/apps/postgresql
```

The Home Assistant exclusion keeps Bambu Lab printer media from dominating the
offsite repository. The PostgreSQL exclusion avoids treating a file-by-file copy
of a running database cluster as a dependable restore artifact. Immich creates a
logical PostgreSQL dump below `/var/lib/apps/immich/database-backups`, which is
included in restic instead.

SQLite files such as Home Assistant and n8n databases remain included as app
state. If the printer media matters, back it up separately or remove that
exclude from `hosts/nixos-server/storage.nix`.
