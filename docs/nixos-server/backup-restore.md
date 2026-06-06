# Backup And Restore

## What Nix Manages

NixOS manages the normal backup/rollback machinery:

- `services.snapper`: creates local `/var/lib` snapshots every 15 minutes.
- `services.restic.backups.home-assistant`: backs up app data to Dropbox every
  30 minutes.
- `virtualisation.oci-containers`: runs Home Assistant and the migrated add-on
  apps with explicit `/var/lib/...` storage.

You should not normally run backup commands by hand. The manual commands below
are for setup checks, “did it work?” verification, and emergency restore.

## Two Different Rollbacks

There are two kinds of state:

| Thing | Where it lives | How to roll back |
| --- | --- | --- |
| NixOS config | Git repo | Check out an older commit and rebuild |
| Home Assistant/app data | `/var/lib/...` | Restore a Snapper snapshot or restic backup |

That split is intentional. If a Home Assistant edit breaks something, you can
roll back `/var/lib/home-assistant` without rolling back the whole NixOS system.

## App Data Locations

Each app gets a plain directory:

- Home Assistant: `/var/lib/home-assistant`
- AdGuard Home: `/var/lib/adguard`
- Matter Server: `/var/lib/matter-server`
- n8n: `/var/lib/n8n`
- OpenClaw: `/var/lib/openclaw`
- Tailscale: `/var/lib/tailscale`
- Future MQTT/Zigbee/Z-Wave/ESPHome data:
  - `/var/lib/mosquitto`
  - `/var/lib/zigbee2mqtt`
  - `/var/lib/zwave-js-ui`
  - `/var/lib/esphome`

These directories are what Snapper snapshots and restic backs up.

## What About Secrets?

Secrets are split into two buckets:

| Secret | Where it lives | Backed up how |
| --- | --- | --- |
| Home Assistant `secrets.yaml` | `/var/lib/home-assistant/secrets.yaml` | Snapper and restic |
| AdGuard admin hash/config secrets | `/var/lib/adguard/conf` | Snapper and restic |
| n8n credentials database | `/var/lib/n8n` | Snapper and restic |
| OpenClaw app config/passwords | `/var/lib/openclaw` if app-owned | Snapper and restic |
| Tailscale machine state | `/var/lib/tailscale` | Snapper and restic |
| OpenClaw env passwords/tokens | `/root/secrets/openclaw.env` | Separate encrypted copy |
| Tailscale first-boot auth key | `/root/secrets/tailscale-authkey` | Separate encrypted copy |
| Dropbox/rclone config | `/root/secrets/rclone.conf` | Separate encrypted copy |
| Restic repository password | `/root/secrets/restic-password` | Separate encrypted copy |

The `/root/secrets` files are the keys needed before restic can restore
anything. Keep copies in a password manager, `sops-nix`, or an encrypted archive
whose password is stored somewhere you can reach after the Pi dies.

## Fast Local Restore

Use this when you made a bad config change and want to go back quickly.

1. Stop the affected app.
2. Pick a snapshot.
3. Restore only the relevant files.
4. Start the app again.

Example for Home Assistant:

```sh
sudo systemctl stop docker-home-assistant.service
sudo snapper -c var-lib list
sudo snapper -c var-lib undochange <old>..<new>
sudo systemctl start docker-home-assistant.service
```

`<old>..<new>` is the snapshot range Snapper shows from `snapper list`. Think of
this as “make `/var/lib` look like it did before the bad edit.”

## Offsite Restore From Dropbox

Use this if the local disk is lost or the local snapshots are not enough.

List encrypted backup points:

```sh
sudo restic -r rclone:dropbox:Backups/nixos-home-assistant/restic \
  --password-file /root/secrets/restic-password snapshots
```

Restore Home Assistant into a temporary directory first:

```sh
sudo restic -r rclone:dropbox:Backups/nixos-home-assistant/restic \
  --password-file /root/secrets/restic-password restore latest \
  --target /tmp/ha-restore \
  --include /var/lib/home-assistant
```

Inspect `/tmp/ha-restore` before replacing live files. This avoids turning one
mistake into two mistakes with a tiny hat.

## Media Policy

The only default restic exclusion is:

```text
/var/lib/home-assistant/www/media/ha-bambulab
```

The raw HAOS backup showed that Bambu Lab printer media dominates the Home
Assistant backup size. SQLite files such as Home Assistant and n8n databases are
included because they are app state. If the printer media matters, back it up
separately or remove that exclude from
`profiles/nixos-server/hosted-stack.nix`.
