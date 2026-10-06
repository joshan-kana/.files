# Jellyfin

Jellyfin runs natively on `nixos-server` as a private media service.

## Storage

| Path | Purpose | Protection |
| --- | --- | --- |
| `/var/lib/apps/jellyfin` | Jellyfin configuration, database, metadata, and logs | Snapper plus the server app-data Restic backup |
| `/var/cache/jellyfin` | Cache and transient transcoding data | Ephemeral; excluded from app-data backup |
| `/srv/vault/media` | Media library files | Vault ZFS mirror plus Sanoid snapshots; no general offsite Vault backup |

The primary user and `server-data` group can manage `/srv/vault/media`. The Jellyfin service joins `server-data` so it can scan the library, while its systemd sandbox exposes the media path read-only.

## Access

Use Jellyfin on TCP port `8096` through the private home network:

- LAN: `http://nixos-server.home:8096`
- Remote: use the existing private Tailscale path to `nixos-server`; there is no public Funnel or WAN exposure for Jellyfin.

The firewall opens `8096` only on the server LAN interface. Tailscale remains a trusted private interface under the existing server networking policy. Jellyfin discovery ports are not opened, so clients should be pointed at the server explicitly.

## Initial setup

After the configuration is deployed:

1. Open the Jellyfin web UI and create the initial administrator account.
2. Add libraries from directories under `/srv/vault/media`.
3. Keep library content on the Vault; do not put cache or transient transcoding data there.
4. Configure library presentation, metadata providers, users, and transcoding preferences in Jellyfin itself.

The host exposes its Intel graphics stack to Jellyfin and grants the service access to the `render` and `video` device groups. Jellyfin's codec and transcoding choices remain application-managed rather than being forced by Nix.

## Post-deployment checks

Verify the service and private port:

```sh
systemctl status jellyfin --no-pager
ss -ltn | grep ':8096'
```

Confirm the persistent and media paths:

```sh
systemctl show jellyfin -p RequiresMountsFor -p ReadOnlyPaths
stat /var/lib/apps/jellyfin
stat /srv/vault/media
```

Then test the web UI from a LAN client and through the existing Tailscale remote path. Confirm direct playback first, followed by one controlled transcoding test if required by the client or media format.
