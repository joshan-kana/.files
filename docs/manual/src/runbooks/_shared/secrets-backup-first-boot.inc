## Verify secrets backup

Skip this section when `SECRETS_BACKUP_ENABLED=false`.

When recovering an existing host, verify the restored repository:

```sh
if [[ "$SECRETS_BACKUP_ENABLED" == true ]]; then
  sudo restic-secrets snapshots --latest 1
fi
```

On first-ever provisioning, populate the host's normal secrets tree first. Then initialize the repository once, run the first backup, and verify it:

```sh
if [[ "$SECRETS_BACKUP_ENABLED" == true ]]; then
  sudo restic-secrets init
  sudo systemctl start restic-backups-secrets.service
  sudo restic-secrets snapshots --latest 1
fi
```

Do not run `restic-secrets init` when recovering an existing repository.
