# Backup and restore

Use this runbook when recovering application state, runtime secrets, account state, or Vault data. Prefer the least destructive recovery mechanism that solves the problem.

## Current evaluated backup configuration

{{#include ../generated/backup-reference.md}}

The shell snippets below use path variables generated from the same evaluated `nixos-server` configuration:

```sh
{{#include ../generated/server-env.sh}}
```

Run that block in the shell before using snippets that reference those variables.

## Quick recovery guide

| Problem | First move |
| --- | --- |
| NixOS change broke the server | `sudo nixos-rebuild switch --rollback` |
| One app is broken | Inspect local Snapper snapshots first |
| Secret is missing or damaged | Inspect `restic-secrets` snapshots |
| Local app data is gone | Inspect `restic-apps` snapshots |
| Whole server was lost | Restore secrets/account state, app data, then application databases |
| Vault file is missing or damaged | Recover from a ZFS snapshot before considering rollback |

Before restoring mutable data, stop the service that writes to it and inspect the recovery source. When the machine still works, restore into a temporary directory before replacing live state.

```sh
sudo restic-secrets snapshots
sudo restic-apps snapshots
sudo snapper -c apps list
systemctl --failed --no-pager
```

## Restore order

1. Identify whether the affected state belongs to NixOS configuration, application data, runtime secrets/account state, or Vault data.
2. Stop the service or container that writes to the affected state.
3. List and inspect the available snapshots or backups.
4. Restore into a temporary location when practical and compare it with live state.
5. Restore only the smallest affected path.
6. Start the service and verify it before continuing.

Do not begin with `rsync --delete`, `snapper undochange` across the whole application tree, `zfs rollback`, or `zfs destroy`. Those operations can replace current state. Copy-based recovery is safer when it is sufficient.

## NixOS configuration rollback

NixOS configuration is Git/Nix state, not application-data backup state.

For the immediately previous system generation:

```sh
sudo nixos-rebuild switch --rollback
```

For a specific older repository revision, check out or inspect that revision in a separate worktree, build it, and switch only after reviewing the resulting system change.

## Secret and account-state recovery

`restic-secrets` protects the paths shown in the generated configuration above. The repository password and rclone bootstrap material remain outside Git.

Restore one secret into a temporary directory first:

```sh
{{#include ../generated/server-env.sh}}
secret="$SERVER_SECRETS_DIR/n8n.env"
restore_dir="$(mktemp -d)"

sudo restic-secrets restore latest \
  --target "$restore_dir" \
  --include "$secret"

sudo ls -l "$restore_dir$secret"
```

After inspection, stop the consuming service and install the recovered file with the ownership and mode expected by that service.

After total machine loss, restore the backup bootstrap credentials first, then restore the secrets repository before application state:

```sh
{{#include ../generated/server-env.sh}}
sudo restic-secrets restore latest --target /
sudo restic-apps restore latest --target / --include "$APP_DATA_ROOT"
```

For a bare-metal replacement, use [Install or recover the NixOS server](server-install.md), which covers the bootstrap sequence before the installed system exists.

## Application-data recovery with Restic

List snapshots:

```sh
sudo restic-apps snapshots
```

Restore all application data:

```sh
{{#include ../generated/server-env.sh}}
sudo restic-apps restore latest \
  --target / \
  --include "$APP_DATA_ROOT"
```

Restore one application, using n8n as the example:

```sh
{{#include ../generated/server-env.sh}}
sudo restic-apps restore latest \
  --target / \
  --include "$APP_DATA_ROOT/n8n"
```

The generated backup reference above is authoritative for the paths that are currently included or excluded. Do not maintain a second list in this runbook.

## Fast local application-data recovery with Snapper

Use Snapper when the local application-data filesystem is intact and a recent local snapshot contains the desired state.

List snapshots and preview a range:

```sh
sudo snapper -c apps list
sudo snapper -c apps status <old>..<new>
```

Restore a single application only after stopping it:

```sh
{{#include ../generated/server-env.sh}}
sudo systemctl stop docker-n8n.service
sudo snapper -c apps undochange <old>..<new> "$APP_DATA_ROOT/n8n"
sudo systemctl start docker-n8n.service
```

A whole-tree undo is substantially more destructive because unrelated applications are returned to the same point in time. Use it only when that is explicitly intended:

```sh
{{#include ../generated/server-env.sh}}
sudo snapper -c apps undochange <old>..<new> "$APP_DATA_ROOT"
sudo nixos-rebuild switch --flake "$DOTFILES_REPO#nixos-server"
```

## PostgreSQL-backed applications

Paperless and Immich require compatible database state in addition to their file storage. The current locations used by the recovery commands are generated from the evaluated configuration:

```sh
{{#include ../generated/server-env.sh}}
```

Stop writers and the automatic Paperless database backup before replacing database state:

```sh
sudo systemctl stop \
  paperless-web.service \
  paperless-consumer.service \
  paperless-scheduler.service \
  paperless-task-queue.service \
  immich-server.service \
  postgresqlBackup-paperless.timer
```

Restore the relevant logical dumps into a temporary directory:

```sh
{{#include ../generated/server-env.sh}}
snapshot=<snapshot-id>
restore_dir="$(mktemp -d)"

sudo restic-apps restore "$snapshot" \
  --target "$restore_dir" \
  --include "$PAPERLESS_BACKUP_ROOT/paperless.sql.gz" \
  --include "$IMMICH_BACKUP_ROOT"
```

Verify compressed dumps with `gzip -t` before loading them. Do not use an incomplete `*.tmp` dump.

Restore Paperless:

```sh
{{#include ../generated/server-env.sh}}
restore_dir=<temporary-restore-directory>
paperless_dump="$restore_dir$PAPERLESS_BACKUP_ROOT/paperless.sql.gz"

sudo gzip -t "$paperless_dump"
sudo -u postgres dropdb --if-exists --force paperless
sudo gzip -cd "$paperless_dump" | \
  sudo -u postgres psql -v ON_ERROR_STOP=1 -d postgres
```

Restore Immich from a complete dump selected from `$IMMICH_BACKUP_ROOT`. The dump expects an empty `immich` database:

```sh
immich_dump=<path-to-complete-immich-sql.gz>
sudo gzip -t "$immich_dump"
sudo -u postgres dropdb --if-exists --force immich
sudo -u postgres createdb --owner=immich immich
sudo gzip -cd "$immich_dump" | \
  sudo -u postgres psql -v ON_ERROR_STOP=1 -d immich
```

Start the applications again and verify their state before allowing normal backup timers to continue.

## Vault snapshot recovery

Vault recovery is deliberately separate from application-data Restic/Snapper recovery. For browsing snapshots, copying individual files, cloning snapshots for inspection, whole-dataset rollback warnings, and pool-import recovery, use [Vault ZFS storage](vault-storage.md).

Do not use a NixOS generation rollback to undo an application database migration. Reverting the service binary does not automatically revert migrated persistent state.
