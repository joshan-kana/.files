# Backup And Restore

## What Nix Manages

NixOS manages the normal backup/rollback machinery:

- `services.snapper`: creates local `/var/lib` snapshots every 15 minutes.
- `services.restic.backups.home-assistant`: backs up app data to Dropbox every
  30 minutes.
- `virtualisation.oci-containers` and native services: run the hosted apps with
  explicit persistent storage.

You should not normally run backup commands by hand. The manual commands below
are for setup checks, “did it work?” verification, and emergency restore.

## Two Different Rollbacks

There are two kinds of state:

| Thing | Where it lives | How to roll back |
| --- | --- | --- |
| NixOS config | Git repo | Check out an older commit and rebuild |
| Container app data | `/var/lib/apps` | Restore a Snapper snapshot or restic backup |

That split is intentional. If an app edit breaks something, restore app data
without rolling back the whole NixOS system.

## App Data Locations

Container app data lives under one parent directory:

```text
/var/lib/apps
```

Each app gets a plain child directory, for example:

```text
/var/lib/apps/home-assistant
/var/lib/apps/adguard
/var/lib/apps/matter-server
/var/lib/apps/n8n
/var/lib/apps/openclaw
/var/lib/apps/openclaw-auth
```

Future container apps should store mutable data under `/var/lib/apps` so the
normal backup and restore flow includes them automatically.

Tailscale is a native service and uses its own state outside `/var/lib/apps`.
Normal replacement installs enrol with `/root/secrets/tailscale-authkey` instead
of restoring an old Tailscale machine identity.

## Restic Repository

The offsite restic repository is stored through the `dropbox` rclone remote at:

```text
Archives/Backups/nixos-server
```

The full repository URI used by NixOS is:

```text
rclone:dropbox:Archives/Backups/nixos-server
```

## What About Secrets?

Secrets are split into two buckets:

| Secret | Where it lives | Backed up how |
| --- | --- | --- |
| Home Assistant `secrets.yaml` | `/var/lib/apps/home-assistant/secrets.yaml` | Snapper and restic |
| AdGuard admin hash/config secrets | `/var/lib/apps/adguard/conf` | Snapper and restic |
| n8n credentials database | `/var/lib/apps/n8n` | Snapper and restic |
| n8n runtime secrets | `/root/secrets/n8n.env` | Separate encrypted copy |
| OpenClaw app config/passwords | `/var/lib/apps/openclaw` | Snapper and restic |
| OpenClaw auth profile secrets | `/var/lib/apps/openclaw-auth` | Snapper and restic |
| OpenClaw env passwords/tokens | `/root/secrets/openclaw.env` | Separate encrypted copy |
| Tailscale first-boot auth key | `/root/secrets/tailscale-authkey` | Separate encrypted copy |
| Dropbox/rclone config | `/root/secrets/rclone.conf` | Separate encrypted copy |
| Restic repository password | `/root/secrets/restic-password` | Separate encrypted copy |

The `/root/secrets` files are the keys needed before restic can restore
anything. Keep copies in a password manager, `sops-nix`, or an encrypted archive
whose password is stored somewhere you can reach after the Pi dies.

## Fast Local Restore

Use this when you made a bad config change and want to go back quickly.

1. Stop the affected app if it is running.
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
sudo env RCLONE_CONFIG=/root/secrets/rclone.conf \
  restic -r rclone:dropbox:Archives/Backups/nixos-server \
  --password-file /root/secrets/restic-password snapshots
```

Restore all container app data on a replacement server:

```sh
sudo env RCLONE_CONFIG=/root/secrets/rclone.conf \
  restic -r rclone:dropbox:Archives/Backups/nixos-server \
  --password-file /root/secrets/restic-password restore latest \
  --target / \
  --include /var/lib/apps
```

Restore one app if only that app is broken:

```sh
sudo env RCLONE_CONFIG=/root/secrets/rclone.conf \
  restic -r rclone:dropbox:Archives/Backups/nixos-server \
  --password-file /root/secrets/restic-password restore latest \
  --target / \
  --include /var/lib/apps/n8n
```

## Media Policy

The only default restic exclusion is:

```text
/var/lib/apps/home-assistant/www/media/ha-bambulab
```

The raw HAOS backup showed that Bambu Lab printer media dominates the Home
Assistant backup size. SQLite files such as Home Assistant and n8n databases are
included because they are app state. If the printer media matters, back it up
separately or remove that exclude from
`profiles/nixos-server/hosted-stack.nix`.
