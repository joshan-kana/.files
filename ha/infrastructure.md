# Home Assistant Infrastructure

## What Runs Where

Everything runs on the Raspberry Pi NixOS host.

| App | How it runs | URL/port | Data |
| --- | --- | --- | --- |
| Home Assistant | Docker/OCI container | `http://<server>:8123` | `/var/lib/home-assistant` |
| AdGuard Home | Docker/OCI container | DNS `:53`, setup/admin `:3000` | `/var/lib/adguard` |
| Matter Server | Docker/OCI container | `:5580`, host networking | `/var/lib/matter-server` |
| n8n | Docker/OCI container | `http://<server>:5678` | `/var/lib/n8n` |
| OpenClaw | Optional Docker/OCI container | terminal `:7681`, gateway `:18789` | `/var/lib/openclaw` |
| Twingate | Optional Docker/OCI container | no public port | env file in `/root/secrets` |

NixOS declares the containers, ports, directories, backup timers, and snapshot
policy. The app config/data itself stays as editable files under `/var/lib/...`.

## Why The Restic Paths Are Options

These module options:

```nix
services.homeAssistantStack.backups.passwordFile
services.homeAssistantStack.backups.rcloneConfigFile
```

are used here:

```nix
services.restic.backups.home-assistant.passwordFile = cfg.backups.passwordFile;
services.restic.backups.home-assistant.rcloneConfigFile = cfg.backups.rcloneConfigFile;
```

They are not secrets and they are not the files themselves. They are only paths
to runtime files that must exist on the server:

- `/root/secrets/restic-password`
- `/root/secrets/rclone.conf`

The paths are options so the host can move them later without editing the module
internals. The secret contents stay out of Git and out of the Nix store.

## Local Rollback

Snapper snapshots `/var/lib` every 15 minutes. Retention is:

- 48 hourly snapshots
- 14 daily snapshots
- 8 weekly snapshots
- 12 monthly snapshots

This is for fast “I broke Home Assistant” recovery.

## Dropbox Backup

Restic backs up the app data every 30 minutes to Dropbox through rclone:

```text
rclone:dropbox:Backups/nixos-home-assistant/restic
```

Restic encrypts data before upload. Dropbox receives encrypted restic repository
data, not raw Home Assistant files.

## Connecting Dropbox

This is the one part Nix cannot fully do for you because Dropbox requires an
interactive account authorization token.

On a machine with a browser:

```sh
rclone config
```

Create a Dropbox remote named exactly:

```text
dropbox
```

If configuring from the headless Pi, use rclone remote authorization:

```sh
rclone authorize dropbox
```

Put the finished rclone config here on the Pi:

```text
/root/secrets/rclone.conf
```

Create the restic password file:

```sh
sudo install -d -m 0700 /root/secrets
sudo sh -c 'umask 077; openssl rand -base64 32 > /root/secrets/restic-password'
sudo chmod 0400 /root/secrets/restic-password /root/secrets/rclone.conf
```

After that, NixOS owns the backup timer. You can check it with:

```sh
systemctl list-timers 'restic*'
systemctl status restic-backups-home-assistant.service
```

## OpenClaw

OpenClaw is declared but disabled by default because you wanted to reset it.
Fresh state will live in:

```text
/var/lib/openclaw
```

Enable it in `profiles/nixos-server/configuration_nixos-server.nix`:

```nix
services.homeAssistantStack.containers.openclaw.enable = true;
```

Before enabling, confirm the image tag in `modules/home-assistant-stack.nix`.
The current default is the tag found in the HAOS backup:

```text
docker.io/17e0cc66/aarch64-addon-openclaw_assistant:0.5.77
```

If OpenClaw publishes a preferred upstream image, set that image explicitly:

```nix
services.homeAssistantStack.containers.openclaw = {
  enable = true;
  image = "example/openclaw:version";
};
```

## References

- rclone Dropbox backend: https://rclone.org/dropbox/
- rclone remote authorization: https://rclone.org/remote_setup/
- restic rclone backend: https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html
