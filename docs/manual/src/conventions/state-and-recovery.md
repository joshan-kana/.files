# State and recovery

**Convention:** Persistent data must have an intentional location, identity, backup boundary, and recovery path. A successful build or service restart is not evidence that important data can be restored.

## Storage placement

On the home server, persistent application configuration and state normally live under `config.dotfiles.server.storage.appData.root`. Large user data belongs under `config.dotfiles.server.storage.dataRoot.path`. A dedicated mount or documented upstream requirement can justify an exception.

Do not duplicate filesystem layout constants in multiple modules. Prefer existing shared storage policy and app-owned paths. Each app configures its own directories, ownership, and backup integration; shared storage infrastructure manages the filesystems and mounts.

Prefer declarative systemd directories, user/group ownership, and tmpfiles rules to startup permission-repair scripts. Where Userborn preserves service identities across rebuilds, recover its identity database along with application data.

## Backup boundaries

Keep secrets backup, app-state backup, filesystem snapshots, and Vault recovery conceptually distinct. None alone covers all recovery needs. Declare app-specific backup coverage where the app is configured and prefer verified paths to broad guesses that may miss bind mounts.

Credentials remain runtime-only. Backups of secret material must be encrypted; never embed passwords or tokens in store paths or a runbook.

## Changes and validation

For data-moving changes, inspect the current mounted layout, preservation requirements, and backup status before execution. Do not migrate or delete application state as a side effect of a formatting or module-ownership PR.

Run safe evaluation checks first; verify filesystem ownership and service behavior on the actual host when applicable. For migrations, document an explicit restore or rollback route and test it where practical.

The manual [backup and application recovery](../runbooks/nixos-server/backup-recovery.md) and [Vault/ZFS recovery](../runbooks/nixos-server/vault-zfs-recovery.md) runbooks own operational commands. Higher-level policy is in [Server Backups](https://github.com/joshan-kana/infrastructure-docs/blob/main/docs/NIXOS_SERVER_BACKUPS.md).
