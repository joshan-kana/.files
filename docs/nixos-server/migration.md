# Home Assistant Migration

This document describes the one-time migration from an exported Home Assistant OS backup into the NixOS server app-data layout.

## Source Backup

Parsed backup: Home Assistant manual backup export.

Do not commit the raw backup archive, extracted backup folders, or secrets.
Keep any working inspection copy outside Git. It is not imported by NixOS and
is not live server state. For future exports, prefer Home Assistant's own
backup UI plus standard inspection tools such as `tar`, `jq`, and `yq`; avoid
keeping one-off parser scripts in this repo.

## Current Add-on Mapping

| HAOS add-on | NixOS target | Notes |
| --- | --- | --- |
| Home Assistant | `home-assistant` OCI container | Config/data lives in `/var/lib/apps/home-assistant`. |
| AdGuard Home | `adguard` OCI container | Config lives in `/var/lib/apps/adguard/conf`; runtime work data lives in `/var/lib/apps/adguard/work`. DNS/admin are served from the dedicated AdGuard LAN IP. |
| Matter Server | `matter-server` OCI container | Data lives in `/var/lib/apps/matter-server`; uses host networking for discovery. |
| n8n | `n8n` OCI container | Data lives in `/var/lib/apps/n8n`. |
| OpenClaw Assistant | `openclaw` OCI container | Restore `.openclaw` to `/var/lib/apps/openclaw`; restore `.config/openclaw` to `/var/lib/apps/openclaw-auth` if present. |
| Twingate Connector | Replaced by Tailscale | Tailscale is managed by the NixOS service and enrols from the bootstrap auth key. |
| Studio Code Server | Not migrated as an add-on | Use SSH/editor tooling on the NixOS host instead. |
| Get HACS | Not a runtime service | HACS/custom components are part of the Home Assistant config restore. |

## Restore Order

1. Install NixOS with the server image.
2. Copy the repo to `/home/joshan/.files`.
3. Install `/root/secrets`.
4. Copy the extracted Home Assistant backup to `/tmp/ha-backup`.
5. Restore app data into `/var/lib/apps/...`.
6. Switch the profile.

## Restore App Data

Run this after the install guide has copied the extracted Home Assistant backup
to `/tmp/ha-backup` on the server:

```sh
ssh -t joshan@192.168.1.3 '
  set -e

  sudo install -d -m 0750 \
    /var/lib/apps/home-assistant \
    /var/lib/apps/adguard/conf \
    /var/lib/apps/adguard/work \
    /var/lib/apps/matter-server \
    /var/lib/apps/n8n \
    /var/lib/apps/openclaw \
    /var/lib/apps/openclaw-auth

  sudo rsync -a --delete /tmp/ha-backup/homeassistant/data/ /var/lib/apps/home-assistant/
  sudo rsync -a --delete /tmp/ha-backup/a0d7b954_adguard/data/adguard/ /var/lib/apps/adguard/conf/
  sudo rsync -a --delete /tmp/ha-backup/core_matter_server/data/ /var/lib/apps/matter-server/
  sudo rsync -a --delete /tmp/ha-backup/3cfc8f0f_hass-n8n/data/n8n/.n8n/ /var/lib/apps/n8n/

  if [ -d /tmp/ha-backup/homeassistant/data/.openclaw ]; then
    sudo rsync -a --delete /tmp/ha-backup/homeassistant/data/.openclaw/ /var/lib/apps/openclaw/
  fi

  if [ -d /tmp/ha-backup/homeassistant/data/.config/openclaw ]; then
    sudo rsync -a --delete /tmp/ha-backup/homeassistant/data/.config/openclaw/ /var/lib/apps/openclaw-auth/
  fi

  sudo chown -R root:root /var/lib/apps
  sudo nixos-rebuild switch --flake /home/joshan/.files#nixos-server
'
```

## Restore Paths

| HAOS backup path | NixOS target |
| --- | --- |
| `/tmp/ha-backup/homeassistant/data/` | `/var/lib/apps/home-assistant/` |
| `/tmp/ha-backup/a0d7b954_adguard/data/adguard/` | `/var/lib/apps/adguard/conf/` |
| `/tmp/ha-backup/core_matter_server/data/` | `/var/lib/apps/matter-server/` |
| `/tmp/ha-backup/3cfc8f0f_hass-n8n/data/n8n/.n8n/` | `/var/lib/apps/n8n/` |
| `/tmp/ha-backup/homeassistant/data/.openclaw/` | `/var/lib/apps/openclaw/` |
| `/tmp/ha-backup/homeassistant/data/.config/openclaw/` | `/var/lib/apps/openclaw-auth/` |

`/var/lib/apps/adguard/work` is not restored from the Home Assistant backup.
AdGuard recreates it.

OpenClaw state is restored only when the `.openclaw` or `.config/openclaw`
directories are present in the Home Assistant backup.

## Parsed Backup Observations

- Home Assistant includes HACS and custom components.
- The Bambu Lab integration contributes most media weight under `www/media/ha-bambulab`.
- Home Assistant has 35 device registry entries and 235 entity registry entries in the parsed backup.
- OpenClaw state is migrated from the Home Assistant backup when present.
