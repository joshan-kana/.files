# Home Assistant Migration

## Source Backup

Parsed backup: `automatic_backup_2026_5_4`

Do not commit the raw backup archive, extracted backup folders, or secrets. Use
`scripts/ha-backup-inventory` to regenerate the sanitized inventory after a new
backup export:

```sh
scripts/ha-backup-inventory /Users/joshan/Downloads/automatic_backup_2026_5_4 \
  --output ha/sanitized/backup-inventory.md
```

## Current Add-on Mapping

| HAOS add-on | NixOS target | Notes |
| --- | --- | --- |
| Home Assistant | `home-assistant` OCI container | Config/data lives in `/var/lib/home-assistant`. |
| AdGuard Home | `adguard` OCI container | Config/data lives in `/var/lib/adguard`. DNS port 53 is exposed. |
| Matter Server | `matter-server` OCI container | Uses host networking for discovery. |
| n8n | `n8n` OCI container | Data lives in `/var/lib/n8n`. |
| Twingate Connector | Optional OCI container | Disabled until `/root/secrets/twingate-connector.env` is provided. |
| Studio Code Server | Not migrated as an add-on | Use SSH/editor tooling on the NixOS host instead. |
| Get HACS | Not a runtime service | HACS/custom components are part of the HA config restore. |
| OpenClaw Assistant | Ignored | Intentionally reset from scratch. |

## Restore Order

1. Install NixOS with a Btrfs `/var/lib` subvolume if possible.
2. Copy the repo to `/home/joshan/.files`.
3. Copy the target hardware configuration to `/etc/nixos/hardware-configuration.nix`.
4. Create `/root/secrets/restic-password` and `/root/secrets/rclone.conf`.
5. Restore Home Assistant and app data into `/var/lib/...`.
6. Switch the profile:

```sh
sudo nixos-rebuild switch --flake /home/joshan/.files#nixos-server
```

## Parsed Backup Observations

- Home Assistant includes HACS and custom components.
- The Bambu Lab integration contributes most media weight under `www/media/ha-bambulab`.
- Home Assistant has 35 device registry entries and 235 entity registry entries in the parsed backup.
- OpenClaw data is deliberately excluded from inventory and migration decisions.
