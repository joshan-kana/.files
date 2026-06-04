# Home Assistant Infrastructure

## What Runs Where

Everything runs on the Raspberry Pi NixOS host.

| App | How it runs | URL/port | Data |
| --- | --- | --- | --- |
| Home Assistant | Docker/OCI container | `http://<server>:8123` | `/var/lib/home-assistant` |
| AdGuard Home | Docker/OCI container on its own LAN IP | DNS/admin on the AdGuard IP | `/var/lib/adguard` |
| Matter Server | Docker/OCI container | `:5580`, host networking | `/var/lib/matter-server` |
| n8n | Docker/OCI container | `http://<server>:5678` | `/var/lib/n8n` |
| OpenClaw | Docker/OCI container | terminal `:7681`, gateway `:18789` | `/var/lib/openclaw` |
| Tailscale | NixOS service | no public port | `/var/lib/tailscale` |

NixOS declares the containers, ports, directories, backup timers, and snapshot
policy. The app config/data itself stays as editable files under `/var/lib/...`.

The stack config lives in:

```text
profiles/nixos-server/home-assistant-stack.nix
```

It is direct server configuration, not a reusable `mkOption` module. To remove a
container, remove its entry from `virtualisation.oci-containers.containers` or
set up a simple local boolean in that same file.

## Binary Caches

The server config declares these Nix substituters:

```text
https://cache.nixos.org/
https://nix-community.cachix.org
https://nixos-raspberrypi.cachix.org
```

`fallback = false` is intentional. If a requested path is not available from the
configured binary caches, Nix fails instead of compiling locally on the Pi. That
keeps updates fast and predictable; the tradeoff is that some updates may need
to wait for cache availability or be built on a stronger machine.

The server uses the Raspberry Pi 4 hardware profile with the mainline NixOS
kernel instead of the Raspberry Pi vendor kernel. That keeps the hardware
configuration Pi-aware while avoiding slow local vendor-kernel builds during
normal updates.

## AdGuard Stable IP

AdGuard uses a Docker macvlan network so it can have a stable LAN IP independent
of the NixOS host address.

Edit these values at the top of
`profiles/nixos-server/home-assistant-stack.nix` before deploying:

```nix
adguardNetwork = {
  name = "adguard_lan";
  parentInterface = "end0";
  subnet = "192.168.1.0/24";
  gateway = "192.168.1.1";
  containerIp = "192.168.1.53";
  hostShimIp = "192.168.1.54";
};
```

`containerIp` is the DNS IP your router/clients should use. Reserve it in your
router or keep it outside the DHCP pool.

`hostShimIp` is a small host-side macvlan address. Without it, the NixOS host
and host-networked Home Assistant can have trouble reaching the AdGuard
container because macvlan isolates the parent host by default. The stack creates
this host-side link as `adguard-shim`.

## How App Configs Are Connected

Each app keeps its normal config format. Nix connects that config to the app by
mounting a host directory into the container.

For AdGuard Home:

| Host path | Container path | Meaning |
| --- | --- | --- |
| `/var/lib/adguard/conf` | `/opt/adguardhome/conf` | AdGuard settings, including `AdGuardHome.yaml` |
| `/var/lib/adguard/work` | `/opt/adguardhome/work` | AdGuard runtime data |

That means AdGuard still reads and writes its own config. Nix only starts the
container and gives it stable storage.

Home Assistant works the same way:

| Host path | Container path |
| --- | --- |
| `/var/lib/home-assistant` | `/config` |

## Why Tmpfiles Creates Directories

`systemd.tmpfiles.rules` in
`profiles/nixos-server/home-assistant-stack.nix` creates the app data
directories and `/root/secrets` with known permissions.

Despite the name, tmpfiles is not only for temporary files. On NixOS it is also
the normal declarative way to create runtime directories. Here it prevents
Docker from auto-creating missing bind-mount directories with implicit defaults.

## Secrets

Runtime secret files go here on the server:

```text
/root/secrets
```

This directory is created by NixOS with `0700` permissions, but the secret file
contents are not stored in Git and are not put in the Nix store.

Current secret files:

| File | Used by |
| --- | --- |
| `/root/secrets/restic-password` | Unlocks the encrypted restic backup repository |
| `/root/secrets/rclone.conf` | Lets rclone connect restic to Dropbox |
| `/root/secrets/tailscale-authkey` | Tailscale first-boot auth key |
| `/root/secrets/openclaw.env` | Optional OpenClaw passwords/tokens as environment variables |

Home Assistant's own `secrets.yaml` stays inside:

```text
/var/lib/home-assistant/secrets.yaml
```

App-owned secret config, such as AdGuard login hashes or OpenClaw config files,
stays in that app's `/var/lib/...` directory unless the app specifically needs
environment variables. Tailscale's ongoing machine identity lives under
`/var/lib/tailscale`.

## Secret Backup Policy

There are two categories:

| Secret type | Backed up by restic? | Restore note |
| --- | --- | --- |
| App secrets under `/var/lib/...` | Yes | They restore with the app data |
| Bootstrap secrets under `/root/secrets` | No | Keep a separate encrypted copy |

`/root/secrets` is deliberately not backed up into the same restic repository.
The important reason: `restic-password` is the key needed to open that
repository. If the only copy of the key is inside the locked backup, restore is
stuck in a silly little logic cupboard.

Use one of these for `/root/secrets`:

- Best simple option: store `restic-password`, `rclone.conf`, and optional app
  env files in a password manager secure note.
- Git-adjacent option: use `sops-nix` later and commit only encrypted secrets to
  the private repo.
- Dropbox option: keep an encrypted archive of `/root/secrets` in Dropbox
  outside the restic repo, and store the archive password in your password
  manager.

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

## Tailscale

Tailscale is managed by the NixOS `services.tailscale` module, not by Docker.
The node state lives in:

```text
/var/lib/tailscale
```

Create a reusable or ephemeral auth key in the Tailscale admin console and put
it here before first boot:

```text
/root/secrets/tailscale-authkey
```

That auth key is bootstrap material, so keep it out of Git. After the machine is
registered, the ongoing Tailscale identity is app state under `/var/lib/tailscale`
and is included in Snapper/restic.

## OpenClaw

OpenClaw runs as part of the server stack. Fresh state will live in:

```text
/var/lib/openclaw
```

Then create the env file for any OpenClaw credentials or tokens:

```sh
sudo install -d -m 0700 /root/secrets
sudo install -m 0400 /dev/null /root/secrets/openclaw.env
sudoedit /root/secrets/openclaw.env
```

Use the environment variable names OpenClaw expects. Keep this file out of Git.
If OpenClaw stores passwords in its own config directory instead, they will live
under `/var/lib/openclaw` and be included in Snapper/restic with the rest of the
app data.

Before enabling, confirm the image tag in
`profiles/nixos-server/home-assistant-stack.nix`.
The image is declared in the OpenClaw container block because NixOS needs the
OCI image name to run the container. The current default is the tag found in the
HAOS backup:

```text
docker.io/17e0cc66/aarch64-addon-openclaw_assistant:0.5.77
```

If OpenClaw publishes a preferred upstream image, change the container image:

```nix
image = "example/openclaw:version";
```

## References

- rclone Dropbox backend: https://rclone.org/dropbox/
- rclone remote authorization: https://rclone.org/remote_setup/
- restic rclone backend: https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html
