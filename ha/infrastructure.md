# Home Assistant Infrastructure

## Services

NixOS declares the host, firewall, Docker/OCI containers, backup timers, and
snapshot policy. Home Assistant and app data stay in mutable directories:

- `/var/lib/home-assistant`
- `/var/lib/adguard`
- `/var/lib/matter-server`
- `/var/lib/n8n`
- `/var/lib/mosquitto`
- `/var/lib/zigbee2mqtt`
- `/var/lib/zwave-js-ui`
- `/var/lib/esphome`

The OCI containers use explicit bind mounts from those directories. Anonymous
Docker volumes are avoided.

## Local Rollback

Snapper snapshots `/var/lib` every 15 minutes. Retention is:

- 48 hourly snapshots
- 14 daily snapshots
- 8 weekly snapshots
- 12 monthly snapshots

Use this when Home Assistant/app config breaks but the NixOS config is fine.

## Offsite Backup

Restic backs up the app data every 30 minutes to Dropbox through rclone:

```text
rclone:dropbox:Backups/nixos-home-assistant/restic
```

Restic encrypts data before upload. Dropbox receives encrypted repository data,
not raw Home Assistant files.

Restic retention is:

- 48 hourly snapshots
- 14 daily snapshots
- 8 weekly snapshots
- 12 monthly snapshots

The Bambu Lab media directory is excluded by default because it dominates the
backup size:

```text
/var/lib/home-assistant/www/media/ha-bambulab
```

## Connecting Dropbox

On a machine with a browser, install/use rclone and run:

```sh
rclone config
```

Create a Dropbox remote named exactly:

```text
dropbox
```

If configuring from the headless Pi, rclone supports remote authorization:

```sh
rclone authorize dropbox
```

Copy the resulting token into the Pi's rclone setup when prompted. Once the
remote works, copy the config to:

```text
/root/secrets/rclone.conf
```

Then create a restic password file:

```sh
sudo install -d -m 0700 /root/secrets
sudo sh -c 'umask 077; openssl rand -base64 32 > /root/secrets/restic-password'
sudo chmod 0400 /root/secrets/restic-password /root/secrets/rclone.conf
```

Initialize and test the repository:

```sh
sudo restic -r rclone:dropbox:Backups/nixos-home-assistant/restic \
  --password-file /root/secrets/restic-password init

sudo systemctl start restic-backups-home-assistant.service
sudo systemctl status restic-backups-home-assistant.service
```

## References

- rclone Dropbox backend: https://rclone.org/dropbox/
- rclone remote authorization: https://rclone.org/remote_setup/
- restic rclone backend: https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html
