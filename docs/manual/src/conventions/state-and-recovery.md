# State and recovery

Persistent data requires deliberate placement, ownership, backup coverage, and a restoration path. Rebuilding a host or restarting a service does not prove data is recoverable.

## Storage ownership

Use the owning host's shared storage policy for application state and large data. An application scope declares its required paths, permissions, and backup participation; the storage scope owns filesystems and mounts.

Derive application paths from shared storage policy. Use declarative state directories and identities, and include identity databases needed to restore permissions.

## Recovery boundaries

Keep configuration rollback, application-state restoration, filesystem snapshots, and encrypted offsite backups separate. None alone substitutes for a complete recovery plan.

Protect encrypted recovery material and verify backup coverage against actual persistent paths, including volumes and bind mounts.

## Changes to persistent data

Inspect mounted paths, service ownership, backup state, and recovery options before a migration. Preserve existing data across ordinary configuration refactors. Do not move, repair, or delete live state as a side effect of a documentation or formatting change.

When state moves, test ownership, application startup and restoration. Use the applicable host's recovery runbooks for procedures and the [backup policy](https://github.com/joshan-kana/infrastructure-docs/blob/main/docs/NIXOS_SERVER_BACKUPS.md) for overarching recovery requirements.
