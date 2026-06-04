# Home Assistant Backup And Restore

## Runtime Data

Keep mutable app data in explicit bind-mounted directories:

- `/var/lib/home-assistant`
- `/var/lib/adguard`
- `/var/lib/matter-server`
- `/var/lib/n8n`
- `/var/lib/mosquitto`
- `/var/lib/zigbee2mqtt`
- `/var/lib/zwave-js-ui`
- `/var/lib/esphome`

Avoid anonymous Docker volumes for Home Assistant-related services. They are
harder to audit, snapshot, and restore.

## Rollback Model

Use Git for Nix config rollback:

```sh
git checkout <known-good-commit>
sudo nixos-rebuild switch --flake /home/joshan/.files#nixos-server
```

Use Snapper for mutable data rollback:

```sh
sudo systemctl stop docker-home-assistant.service
sudo snapper -c var-lib list
sudo snapper -c var-lib undochange <old>..<new>
sudo systemctl start docker-home-assistant.service
```

This intentionally rolls back `/var/lib` without rolling back the Nix profile.

## Dropbox Offsite Backup

The NixOS profile declares a restic repository at:

```text
rclone:dropbox:Backups/nixos-home-assistant/restic
```

Create these files on the server, outside Git:

```text
/root/secrets/restic-password
/root/secrets/rclone.conf
```

The `dropbox` remote in `rclone.conf` must match the repository name above.
The restic job runs every 30 minutes and keeps hourly, daily, weekly, and
monthly snapshots.

## Restore From Restic

List snapshots:

```sh
sudo restic -r rclone:dropbox:Backups/nixos-home-assistant/restic snapshots
```

Restore one app path to a temporary directory:

```sh
sudo systemctl stop docker-home-assistant.service
sudo restic -r rclone:dropbox:Backups/nixos-home-assistant/restic restore latest \
  --target /tmp/ha-restore \
  --include /var/lib/home-assistant
```

Inspect the restored data before replacing live files.

## Media Policy

The backup excludes `/var/lib/home-assistant/www/media/ha-bambulab` by default
because the HAOS backup shows it dominates the data size. Back it up separately
if those printer media files matter.
