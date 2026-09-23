# Home Assistant Migration

This document describes the one-time migration from an exported Home Assistant OS backup into the NixOS server app-data layout. It is a historical migration procedure, not the normal machine-recovery path; current secret recovery uses the dedicated Restic repository documented in `backup-restore.md`.

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
| Home Assistant | native NixOS `home-assistant` service | Config/data lives in `/var/lib/apps/home-assistant`. |
| AdGuard Home | `adguard` OCI container | Config lives in `/var/lib/apps/adguard/conf`; runtime work data lives in `/var/lib/apps/adguard/work`. DNS/admin are served from the dedicated AdGuard LAN IP. |
| Matter Server | Native `services.matter-server` service | Data lives in `/var/lib/apps/matter-server`; the native service uses a stable NixOS system user. |
| n8n | `n8n` OCI container | Data lives in `/var/lib/apps/n8n`. |
| OpenClaw Assistant | `openclaw` OCI container | Restore `.openclaw` to `/var/lib/apps/openclaw`; restore `.config/openclaw` to `/var/lib/apps/openclaw-auth` if present. |
| Twingate Connector | Replaced by Tailscale | Tailscale is managed by the NixOS service and enrols from the bootstrap auth key. |
| Studio Code Server | Not migrated as an add-on | Use SSH/editor tooling on the NixOS host instead. |
| Get HACS | Not a runtime service | HACS/custom components are part of the Home Assistant config restore. |

## Restore Order

1. Install NixOS with the server image.
2. Copy the local repo to `/home/joshan/.files`.
3. Install `/root/secrets`.
4. Extract and stage the Home Assistant backup at `/var/lib/restore/ha-backup`.
5. Restore app data into `/var/lib/apps/...`.
6. Switch the profile.

## Copy And Restore

Run this from the user's machine after the NixOS server has booted and SSH works:

```sh
export SERVER="192.168.1.3"
export REPO_DIR="$HOME/.files"
export SECRETS_DIR="$HOME/.secrets"
export HA_BACKUP_ARCHIVE="$HOME/Downloads/home_assistant_main_backup.tar"
export HA_BACKUP_DIR="$(dirname "$HA_BACKUP_ARCHIVE")/extracted-home-assistant-backup"
export STAGE_DIR="/var/lib/restore/ha-backup"
export APP_DATA_ROOT="/var/lib/apps"

rm -rf "$HA_BACKUP_DIR" &&
  mkdir -p "$HA_BACKUP_DIR" &&
  tar -xf "$HA_BACKUP_ARCHIVE" -C "$HA_BACKUP_DIR" &&
  find "$HA_BACKUP_DIR" -maxdepth 1 -type f -name "*.tar.gz" -exec sh -eu -c '
    for archive do
      dir="${archive%.tar.gz}"
      mkdir -p "$dir"
      tar -xzf "$archive" -C "$dir"
    done
  ' sh {} + &&
  ssh -t "joshan@$SERVER" "
    sudo rm -rf '$STAGE_DIR' /tmp/.secrets &&
    sudo install -d -m 0750 -o joshan -g users '$STAGE_DIR' &&
    mkdir -p /tmp/.secrets /home/joshan/.files
  " &&
  nix shell nixpkgs#rsync -c sh -eu -c '
    rsync -ah --delete --info=progress2 \
      --exclude /result \
      --exclude /.direnv \
      "$REPO_DIR"/ \
      "joshan@$SERVER:/home/joshan/.files/"

    rsync -ah --delete --info=progress2 \
      "$SECRETS_DIR"/ \
      "joshan@$SERVER:/tmp/.secrets/"

    rsync -ah --delete --partial --append-verify --info=progress2 \
      -e "ssh -o ServerAliveInterval=10 -o ServerAliveCountMax=60" \
      "$HA_BACKUP_DIR"/ \
      "joshan@$SERVER:$STAGE_DIR/"
  ' &&
  ssh -t "joshan@$SERVER" '
    set -e

    STAGE_DIR=/var/lib/restore/ha-backup
    APP_DATA_ROOT=/var/lib/apps

    sudo test -f "$STAGE_DIR/homeassistant/data/configuration.yaml"
    sudo test -d "$STAGE_DIR/homeassistant/data/.storage"

    sudo systemctl stop \
      home-assistant.service \
      docker-adguard.service \
      docker-matter-server.service \
      matter-server.service \
      docker-n8n.service \
      docker-openclaw.service \
      2>/dev/null || true

    sudo install -d -m 700 /root/secrets
    sudo cp -a /tmp/.secrets/. /root/secrets/
    sudo chown -R root:root /root/secrets
    sudo chmod 700 /root/secrets
    sudo find /root/secrets -type f -exec chmod 600 {} +

    sudo install -d -m 700 -o joshan -g users /home/joshan/.ssh
    sudo install -m 600 -o joshan -g users /root/secrets/id_ed25519 /home/joshan/.ssh/id_ed25519
    sudo install -m 644 -o joshan -g users /root/secrets/id_ed25519.pub /home/joshan/.ssh/id_ed25519.pub
    sudo -u joshan ssh-keyscan github.com > /tmp/github-known-hosts
    sudo install -m 644 -o joshan -g users /tmp/github-known-hosts /home/joshan/.ssh/known_hosts

    sudo install -d -m 0750 \
      "$APP_DATA_ROOT/home-assistant" \
      "$APP_DATA_ROOT/adguard/conf" \
      "$APP_DATA_ROOT/adguard/work" \
      "$APP_DATA_ROOT/matter-server" \
      "$APP_DATA_ROOT/n8n" \
      "$APP_DATA_ROOT/openclaw" \
      "$APP_DATA_ROOT/openclaw-auth"

    restore_dir() {
      src="$1"
      dest="$2"
      if [ -d "$src" ]; then
        sudo rsync -ah --delete --info=progress2 "$src"/ "$dest"/
      else
        echo "WARN: missing backup path: $src" >&2
      fi
    }

    restore_dir "$STAGE_DIR/homeassistant/data" "$APP_DATA_ROOT/home-assistant"
    restore_dir "$STAGE_DIR/a0d7b954_adguard/data/adguard" "$APP_DATA_ROOT/adguard/conf"
    restore_dir "$STAGE_DIR/core_matter_server/data" "$APP_DATA_ROOT/matter-server"
    restore_dir "$STAGE_DIR/3cfc8f0f_hass-n8n/data/n8n/.n8n" "$APP_DATA_ROOT/n8n"
    restore_dir "$STAGE_DIR/homeassistant/data/.openclaw" "$APP_DATA_ROOT/openclaw"
    restore_dir "$STAGE_DIR/homeassistant/data/.config/openclaw" "$APP_DATA_ROOT/openclaw-auth"

    sudo chown -R root:root "$APP_DATA_ROOT"
    rm -rf /tmp/.secrets /tmp/github-known-hosts
    sudo nixos-rebuild switch --flake /home/joshan/.files#nixos-server
  '
```

## Restore Paths

| HAOS backup path | NixOS target |
| --- | --- |
| `/var/lib/restore/ha-backup/homeassistant/data/` | `/var/lib/apps/home-assistant/` |
| `/var/lib/restore/ha-backup/a0d7b954_adguard/data/adguard/` | `/var/lib/apps/adguard/conf/` |
| `/var/lib/restore/ha-backup/core_matter_server/data/` | `/var/lib/apps/matter-server/` |
| `/var/lib/restore/ha-backup/3cfc8f0f_hass-n8n/data/n8n/.n8n/` | `/var/lib/apps/n8n/` |
| `/var/lib/restore/ha-backup/homeassistant/data/.openclaw/` | `/var/lib/apps/openclaw/` |
| `/var/lib/restore/ha-backup/homeassistant/data/.config/openclaw/` | `/var/lib/apps/openclaw-auth/` |

`/var/lib/apps/adguard/work` is not restored from the Home Assistant backup.
AdGuard recreates it.

OpenClaw state is restored only when the `.openclaw` or `.config/openclaw`
directories are present in the Home Assistant backup.

## Parsed Backup Observations

- Home Assistant includes HACS and custom components.
- The Bambu Lab integration contributes most media weight under `www/media/ha-bambulab`.
- Home Assistant has 35 device registry entries and 235 entity registry entries in the parsed backup.
- OpenClaw state is migrated from the Home Assistant backup when present.
