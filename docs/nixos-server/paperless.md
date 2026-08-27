# Paperless-ngx

Paperless-ngx runs natively on `nixos-server`. The Nix configuration is the
source of truth for service settings and storage paths:
[`modules/server-apps/paperless/`](../../modules/server-apps/paperless/).

## First run

Create the first user:

```sh
sudo paperless-manage createsuperuser
```

## Recovery

Paperless keeps its document media on Vault and its smaller application and
database-backup state with the server app data. A complete recovery needs both.
The consume directory is only an inbox, not the authoritative document archive.
