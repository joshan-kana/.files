# Secrets

Encrypted restic repository for secrets

## Backup

If the secrets repository does not exist, initialise it, run the first backup, and verify it with the generated wrapper:

```sh
sudo restic-secrets init
sudo systemctl start restic-backups-secrets.service
sudo restic-secrets snapshots --latest 1
```

## Restore

Restore into a temporary directory first:

```sh
restore_dir="$(mktemp -d)"
sudo restic-secrets restore latest --target "$restore_dir"
```

Inspect the restored data before copying anything back. For full-host recovery,
restore the complete snapshot only after confirming that replacing the current
state is intended:

```sh
sudo restic-secrets restore latest --target /
```
