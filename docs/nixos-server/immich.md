# Native Immich

Immich runs through the native NixOS `services.immich` module on the Raspberry
Pi. PostgreSQL, Redis, machine learning, and the Immich systemd services use the
module defaults unless explicitly configured otherwise.

## Storage layout

| Path | Purpose | Protection |
| --- | --- | --- |
| `/srv/vault/immich` | Immich-managed uploads, thumbnails, encoded video, profiles, and automatic database backups | Vault ZFS/Sanoid snapshots |
| `/srv/vault/media-library` | Existing photo/video archive added to Immich as an external library | Vault ZFS/Sanoid snapshots |

`services.immich.mediaLocation` is Immich's writable managed-storage root. It is
not the path used to declare an external library. Immich creates and manages its
own storage folders below this location.

The existing `/srv/vault/media-library` archive stays where it is. Add that path
as an external library in Immich and Immich indexes the photos and videos in
place rather than copying them into its managed library. Asset paths, users,
albums, faces, search data, and other application metadata are stored in
Immich's PostgreSQL database.

External-library membership and import paths are application state, so they are
configured in Immich rather than through a `services.immich.*` NixOS option.

The Immich service uses the configured Vault data group. A normal library scan
does not rewrite the source media, but filesystem write access means Immich can
write XMP sidecars or delete an external asset when those actions are requested
through Immich. Use filesystem or service-level read-only permissions if the
archive needs to be immutable to Immich.

PostgreSQL intentionally stays at the native NixOS location instead of being
relocated into `/var/lib/apps`. Redis and the machine-learning cache also keep
their native locations. This avoids custom state plumbing; Immich's automatic
logical database backups under the managed media root provide the application
restore point.

## Deployment

The NixOS Immich module requires a non-default `mediaLocation` to already exist
and be writable by the Immich service. Before the first switch, verify Vault and
create the managed directory:

```sh
findmnt /srv/vault
test -d /srv/vault/media-library
sudo install -d -m 2770 -o root -g server-data /srv/vault/immich
```

Then evaluate and deploy:

```sh
cd /home/joshan/.files

nix eval .#nixosConfigurations.nixos-server.config.services.immich.enable
nix eval --raw .#nixosConfigurations.nixos-server.config.services.immich.host
nix eval --raw .#nixosConfigurations.nixos-server.config.services.immich.mediaLocation

sudo nixos-rebuild dry-activate --flake .#nixos-server
sudo nixos-rebuild switch --flake .#nixos-server
```

Expected values are `true`, `192.168.1.3`, and `/srv/vault/immich` with the
current server defaults.

Verify the native services:

```sh
systemctl status immich-server.service postgresql.service redis-immich.service --no-pager
systemctl status immich-machine-learning.service --no-pager
ss -ltnp | grep ':2283'
sudo -u immich find /srv/vault/media-library -type f -readable -print -quit
```

## Add the existing library

Open the Immich web UI and go to `Administration -> External Libraries`. Create
a library, select its owner, and add this import path:

```text
/srv/vault/media-library
```

Start a scan. The source files remain in `/srv/vault/media-library`; Immich
creates database records and generated content such as thumbnails in its own
managed storage.

## Access

Immich binds to the configured server LAN IP and uses the native default TCP
port `2283`:

```text
http://192.168.1.3:2283
```

Tailnet clients using the existing `192.168.1.0/24` subnet route can use the
same LAN address.

## Raspberry Pi performance

Machine learning is enabled by the native module default. The initial external
library scan can also run metadata extraction, thumbnail generation, face
recognition, smart-search processing, RAW decoding, and video transcoding.
Monitor the Pi during the first large scan:

```sh
journalctl -fu immich-server.service
systemd-cgtop
free -h
uptime
```

If machine learning is too expensive for the Pi, it can be disabled later with
`services.immich.machine-learning.enable = false` or moved to a remote machine.

## Backups and restore

Immich stores file paths and application metadata in PostgreSQL. Its automatic
database dumps are stored below the managed media root at:

```text
/srv/vault/immich/backups
```

Those database dumps contain metadata, not the photos and videos themselves.
Both `/srv/vault/immich` and `/srv/vault/media-library` are covered by the
recursive Vault ZFS/Sanoid snapshot policy, but the Vault is not currently part
of the restic/Dropbox offsite backup. A complete recovery therefore needs both a
compatible Immich database backup and the corresponding media files.

Confirm that Vault snapshots exist after the deployment and first library scan:

```sh
zfs list -t snapshot -r vault/data
```

Use Immich's built-in database restore flow for application/database recovery.
For deleted or damaged files under `/srv/vault`, use the ZFS restore procedures
in `backup-restore.md`.

A NixOS generation rollback is appropriate for a bad Nix configuration, but do
not use it as a database rollback mechanism when it would downgrade the Immich
server. Immich does not support downgrading to an earlier release after a newer
release may have migrated the database. Restore a compatible Immich database
backup instead when application state itself needs to move backward.
