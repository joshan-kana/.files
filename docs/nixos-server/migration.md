# Home Assistant Migration

## Source Backup

Parsed backup: Home Assistant manual backup export

Do not commit the raw backup archive, extracted backup folders, or secrets.
Keep any working inspection copy outside Git. It is not imported by NixOS and
is not live server state. For future exports, prefer Home Assistant's own
backup UI plus standard inspection tools such as `tar`, `jq`, and `yq`; avoid
keeping one-off parser scripts in this repo.

## Current Add-on Mapping

| HAOS add-on | NixOS target | Notes |
| --- | --- | --- |
| Home Assistant | `home-assistant` OCI container | Config/data lives in `/var/lib/home-assistant`. |
| AdGuard Home | `adguard` OCI container | Config/data lives in `/var/lib/adguard`. DNS/admin are served from the dedicated AdGuard LAN IP. |
| Matter Server | `matter-server` OCI container | Uses host networking for discovery. |
| n8n | native `n8n` service | Data lives in `/var/lib/n8n`. |
| Twingate Connector | Replaced by Tailscale | Tailscale is managed by the NixOS service and stores state in `/var/lib/tailscale`. |
| Studio Code Server | Not migrated as an add-on | Use SSH/editor tooling on the NixOS host instead. |
| Get HACS | Not a runtime service | HACS/custom components are part of the HA config restore. |
| OpenClaw Assistant | native `openclaw-gateway` service | Old state ignored; fresh state starts in `/var/lib/openclaw`. |

## Restore Order

1. Install NixOS with a Btrfs `/var/lib` subvolume if possible.
2. Copy the repo to `/home/joshan/.files`.
3. Create `/root/secrets/restic-password` and `/root/secrets/rclone.conf`.
4. Restore Home Assistant and app data into `/var/lib/...`.
5. Switch the profile:

```sh
sudo nixos-rebuild switch --flake /home/joshan/.files#nixos-server
```

## Parsed Backup Observations

- Home Assistant includes HACS and custom components.
- The Bambu Lab integration contributes most media weight under `www/media/ha-bambulab`.
- Home Assistant has 35 device registry entries and 235 entity registry entries in the parsed backup.
- OpenClaw backup state is deliberately excluded from migration; the NixOS server stack starts it fresh.
