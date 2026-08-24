# Paperless-ngx

Paperless-ngx runs natively through NixOS on `nixos-server`. Nix manages the
service, PostgreSQL, Redis, storage paths, and database backups.

## Storage

| Path | Purpose | Protection |
| --- | --- | --- |
| `/srv/vault/paperless/media` | Documents, archive files, thumbnails, and other Paperless media | Vault ZFS mirror + snapshots |
| `/srv/vault/paperless/consume` | Files waiting to be consumed | Vault ZFS mirror + snapshots |
| `/var/lib/apps/paperless` | Paperless application data, search index, and generated secret key | app-data snapshots + restic |
| `/var/lib/apps/paperless/backups` | Logical PostgreSQL dumps | app-data snapshots + restic |

The live PostgreSQL cluster and Redis instance use the native NixOS locations.
Large document data is therefore kept out of restic while the small recovery
state is included in the existing app-data backup policy. Vault document media
is not currently backed up offsite, so it should not be the only copy of
irreplaceable documents.

## First run

Create the first user:

```sh
sudo paperless-manage createsuperuser
```

Then open `http://<server LAN IP>:28981`. Documents can be uploaded through the
web interface. The consume directory is intentionally not world-writable; for a
shell import, copy a file as the Paperless service user:

```sh
sudo -u paperless cp /path/to/document.pdf /srv/vault/paperless/consume/
```

Tika and Gotenberg are not enabled. They are only needed if Office or e-mail
conversion becomes useful; normal PDF and image OCR does not require them.

## Operations

```sh
systemctl status paperless-web.service paperless-consumer.service \
  paperless-task-queue.service paperless-scheduler.service \
  postgresql.service redis-paperless.service --no-pager
systemctl status postgresqlBackup-paperless.timer --no-pager
journalctl -fu paperless-consumer.service
ls -lh /var/lib/apps/paperless/backups
zpool status -x vault
```

## Recovery

A complete recovery needs the Paperless media on Vault plus the corresponding
application data and PostgreSQL dump from `/var/lib/apps`. Restore those before
starting normal use, then let the native NixOS service run its database
migrations as usual.

The consume directory is only an inbox and is not part of the authoritative
document archive.
