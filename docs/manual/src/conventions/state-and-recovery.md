# State and recovery

Persistent data requires deliberate placement, ownership, backup coverage, and a restoration path. Rebuilding a host or restarting a service does not prove data is recoverable.

## Storage ownership

Use the owning host's shared storage policy for application state and large data. An application scope declares its required paths, permissions, and backup participation; the storage scope owns filesystems and mounts.

Do not duplicate root paths across modules or scatter one application's persistent state without a reason. Use declarative state directories and identity management where possible, and include any identity database necessary to restore permissions.

## Recovery boundaries

Keep configuration rollback, application-state restoration, filesystem snapshots, and encrypted offsite backups separate. None alone substitutes for a complete recovery plan.

Keep runtime secrets out of generated configuration and store paths; encrypted recovery material must remain protected. Verify backup coverage against real persistent paths, including volumes and bind mounts.

## Changes to persistent data

Inspect mounted paths, service ownership, backup state, and recovery options before a migration. Preserve existing data across ordinary configuration refactors. Do not move, repair, or delete live state as a side effect of a documentation or formatting change.

Validate the effective configuration and, when state moves, test ownership, application startup, and restoration on the appropriate host. Operational recovery steps belong in the [runbooks](../runbooks/nixos-server/backup-recovery.md); overarching policy belongs in the [recovery handbook](https://github.com/joshan-kana/infrastructure-docs/blob/main/docs/NIXOS_SERVER_BACKUPS.md).
