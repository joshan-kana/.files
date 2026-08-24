# Immich

Immich runs natively through NixOS on `nixos-server`. The Nix configuration is
the source of truth for service options, ports, backup cadence, permissions, and
storage integration; this document only records the stable operational model.

## Storage

| Path | Purpose | Protection |
| --- | --- | --- |
| `/srv/vault/media-library` | Existing photo/video archive indexed as an external library | Vault ZFS mirror + snapshots |
| `/srv/vault/immich` | Immich-managed uploads and generated media | Vault ZFS mirror + snapshots |
| `/var/lib/apps/immich/backups` | Immich logical PostgreSQL dumps | app-data snapshots + restic |

External-library files stay in place. Immich stores its index and application
state in PostgreSQL and writes generated content to its managed storage. It may
modify or delete an external-library file only when an Immich action requests it
and filesystem permissions allow it.

PostgreSQL, Redis, and machine-learning state use the native NixOS defaults.
Database dumps are kept separately under app data so application state can be
restored independently of the bulk media.

## First run

1. Open Immich at `http://<server LAN IP>:2283` and create the first admin.
2. In **Administration → External Libraries**, create a library containing:

   ```text
   /srv/vault/media-library
   ```

3. Start a scan.

Storage paths, PostgreSQL, Redis, and backup scheduling are managed by Nix and
do not need to be configured in the Immich UI.

## Operations

Useful checks:

```sh
systemctl status immich-server.service immich-machine-learning.service \
  postgresql.service redis-immich.service --no-pager
journalctl -fu immich-server.service
zpool status -x vault
ls -lh /var/lib/apps/immich/backups
```

The initial library scan can be CPU-intensive while thumbnails, metadata,
search, faces, and video jobs are populated. This is expected.

## Backup and recovery

The Vault protects both source and Immich-managed media with ZFS redundancy and
snapshots. Immich creates logical PostgreSQL dumps under
`/var/lib/apps/immich/backups`; the Nix configuration defines their cadence and
the surrounding snapshot/backup policy.

A complete Immich recovery needs:

- the relevant media on Vault; and
- a compatible Immich database dump.

Use Immich's supported database restore flow for application-state recovery.
Do not use a NixOS generation rollback to downgrade Immich after a database
migration; restore a database compatible with the server version instead.
