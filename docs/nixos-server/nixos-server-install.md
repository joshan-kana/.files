# NixOS Server Install Guide

This guide installs the full `nixos-server` image onto a Raspberry Pi 4.
It does not use the generic installer image. The SD card is built from this
repo, flashed once, then booted directly into the final server layout.

## Final Layout

- NixOS host: `192.168.1.3`
- AdGuard: `192.168.1.2`
- Router: `192.168.1.1`
- Home Assistant: `http://192.168.1.3:8123`
- Repo on the Pi: `/home/joshan/.files`
- App data root: `/var/lib`
- Runtime secrets: `/root/secrets`
- Boot firmware mount: `/boot`
- Root filesystem: Btrfs label `NIXOS` mounted as the Btrfs top-level
- Btrfs subvolumes: `var-lib`
- Nix store path: `/nix/store`

## What This Image Contains

The built image already includes:

- the Raspberry Pi 4 boot firmware layout on the FAT `FIRMWARE` partition
- the static network configuration for `192.168.1.3`
- the `joshan` user
- the GitHub SSH public key declared in the NixOS config
- the hosted app stack definition
- a 12 GiB seed disk layout that grows to the full SD card on first boot
- `/boot/extlinux` and `/boot/nixos` copied onto the FAT boot partition for U-Boot

The image does not include:

- `/root/secrets`
- restored Home Assistant or app data under `/var/lib`

## Before You Start

You need:

- a Raspberry Pi 4
- a microSD card
- Power and Ethernet to the Pi
- the Home Assistant backup archive on the user's machine
- a local checkout of this repo
- an `aarch64-linux` builder

This repo already has an OrbStack NixOS machine named `nixos`, so this guide
uses that as the builder.

Set these variables on the user's machine:

```sh
export REPO_DIR="$HOME/.files"
export BUILD_HOST="orb"
export HA_BACKUP_ARCHIVE="$HOME/Downloads/home_assistant_main_backup.tar"
export HA_BACKUP_DIR="$(dirname "$HA_BACKUP_ARCHIVE")/extracted-home-assistant-backup"
export SECRETS_DIR="$HOME/.secrets"
```

Extract the Home Assistant backup:

```sh
mkdir -p "$HA_BACKUP_DIR" &&
  tar -xf "$HA_BACKUP_ARCHIVE" -C "$HA_BACKUP_DIR"
```

## Secrets Bundle

The bootstrap bundle should contain:

```text
$SECRETS_DIR/
  restic-password
  rclone.conf
  tailscale-authkey
  n8n.env
  openclaw.env
  id_ed25519
  id_ed25519.pub
```

Run this on the user's machine before copying files to the Pi.
### If secrets do not exist (first run only)
Run this only on the first install if the secrets bundle does not already
exist:

```sh
mkdir -p "$SECRETS_DIR" &&
  chmod 700 "$SECRETS_DIR" &&
  cp "$HOME/.ssh/id_ed25519" "$SECRETS_DIR/" &&
  cp "$HOME/.ssh/id_ed25519.pub" "$SECRETS_DIR/" &&
  openssl rand -base64 32 > "$SECRETS_DIR/restic-password" &&
  touch "$SECRETS_DIR/n8n.env" "$SECRETS_DIR/openclaw.env" &&
  chmod 600 "$SECRETS_DIR/"*
```

Required contents:

- `restic-password`: restic repository password
- `rclone.conf`: rclone config with a Dropbox remote named `dropbox`
- `tailscale-authkey`: reusable Tailscale auth key
- `n8n.env`: runtime environment for the `n8n` container
- `openclaw.env`: runtime environment for the OpenClaw container

Create the Tailscale auth key on the user's machine:

1. Open the Tailscale admin console.
2. Go to `Settings` -> `Keys`.
3. Create an auth key for the server bootstrap.
4. Use a reusable key so the first install does not depend on a one-time token.
5. Leave it non-ephemeral so the server keeps a normal machine identity.
6. Copy the key into the secrets directory:

```sh
printf '%s\n' 'paste-the-tailscale-auth-key-here' > "$SECRETS_DIR/tailscale-authkey" &&
  chmod 600 "$SECRETS_DIR/tailscale-authkey"
```

Authorize Dropbox with rclone on the user's machine:
In the rclone prompts:

1. choose `n` for a new remote
2. name the remote exactly `dropbox`
3. choose Dropbox as the storage provider
4. allow browser authorization when prompted
5. finish and save the remote

Copy the finished rclone config into the secrets directory:

```sh
nix shell nixpkgs#rclone -c rclone config
cp "$HOME/.config/rclone/rclone.conf" "$SECRETS_DIR/rclone.conf" &&
  chmod 600 "$SECRETS_DIR/rclone.conf"
```

Test the remote:

```sh
rclone lsd dropbox:
```

If the authorization has to be done for a headless machine, use rclone's remote
authorization flow from a machine with a browser:

```sh
rclone authorize dropbox
```

Paste the returned token into `rclone config` when it asks for remote
authorization, then copy the resulting `rclone.conf` into `SECRETS_DIR`.

`n8n.env` should at least contain a durable encryption key:

```text
N8N_ENCRYPTION_KEY=replace-this-with-a-long-random-value
```

## Build The SD Card Image

Build the image on a a nix linux machine (Orbstack compatible):

```sh
  syscd
  nix build .#nixosConfigurations.nixos-server.config.system.build.image -L
```

Pull the finished image back to the user's machine (run on orbstack):

```sh
mkdir -p /mnt/mac/Users/joshan/Downloads/nixos-server-image &&
  syscd &&
  IMAGE="$(find -L result -maxdepth 1 -type f -name '*.raw.zst' -print -quit)" &&
  test -n "$IMAGE" &&
  cp -v "$IMAGE" /mnt/mac/Users/joshan/Downloads/nixos-server-image/
```

The output is the full server image, not an installer image.

Optional image sanity check on OrbStack before flashing:

```sh
CHECK_DIR=/mnt/mac/Users/joshan/Downloads/nixos-server-image-check
rm -rf "$CHECK_DIR" && mkdir -p "$CHECK_DIR" &&
  zstd -d -c result/nixos-server.raw.zst > "$CHECK_DIR/nixos-server.raw" &&
  LOOP="$(sudo losetup --find --show --partscan "$CHECK_DIR/nixos-server.raw")" &&
  sudo mkdir -p "$CHECK_DIR/fw" "$CHECK_DIR/root" &&
  sudo mount "${LOOP}p1" "$CHECK_DIR/fw" &&
  sudo mount "${LOOP}p2" "$CHECK_DIR/root" &&
  INIT="$(grep -o 'init=/nix/store/[^ ]*' "$CHECK_DIR/fw/extlinux/extlinux.conf" | cut -d= -f2)" &&
  test -d "$CHECK_DIR/root/nix/store" &&
  test -e "$CHECK_DIR/root$INIT" &&
  echo "image layout OK" &&
  sudo umount "$CHECK_DIR/root" "$CHECK_DIR/fw" &&
  sudo losetup -d "$LOOP"
```

## Flash The SD Card

Run this on the user's machine.

List disks before inserting the SD card:

```sh
diskutil list
```

Insert the SD card, list disks again, and set the new disk number:

```sh
diskutil list
export DISK_N="N"
```

Flash the compressed image directly:

```sh
export IMAGE_ZST="$(find "$HOME/Downloads/nixos-server-image" -name '*.raw.zst' | head -n1)"
test -n "${DISK_N:?DISK_N is not set}"
test -f "$IMAGE_ZST"
diskutil unmountDisk "/dev/disk${DISK_N}" &&
  zstd -d --stdout "$IMAGE_ZST" | sudo dd of="/dev/rdisk${DISK_N}" bs=4m status=progress &&
  sync &&
  diskutil eject "/dev/disk${DISK_N}"
```

## First Boot

1. Power off the old Home Assistant machine if it is still using `192.168.1.3`
   or conflicting with the new plan.
2. Insert the microSD card into the Pi.
3. Connect Ethernet.
4. Connect power.
5. Wait a minute for first boot.

The server should come up directly on `192.168.1.3`.

Test SSH from the user's machine:

```sh
ssh-keygen -R 192.168.1.3 >/dev/null 2>&1 || true
ssh joshan@192.168.1.3
```

Immediately change the temporary first-boot password:

```sh
passwd
```

## Copy Repo, Secrets, And Backup Data

Copy the repo, secrets bundle, and extracted backup to the Pi. Keep the Git metadata so later `git pull` updates work on the server:

```sh
tar --exclude result --exclude .direnv --exclude ha-migration-input --exclude ha-migration-work -C "$REPO_DIR" -cf - . |
  ssh joshan@192.168.1.3 '
    rm -rf /home/joshan/.files &&
    mkdir -p /home/joshan/.files &&
    cd /home/joshan/.files &&
    tar xf -
  ' &&
  ssh joshan@192.168.1.3 '
    rm -rf /tmp/nixos-server-secrets /tmp/ha-backup &&
    mkdir -p /tmp/nixos-server-secrets /tmp/ha-backup
  ' &&
  tar -C "$SECRETS_DIR" -cf - . |
  ssh joshan@192.168.1.3 'cd /tmp/nixos-server-secrets && tar xf -' &&
  tar -C "$HA_BACKUP_DIR" -cf - . |
  ssh joshan@192.168.1.3 'cd /tmp/ha-backup && tar xf -'
```

Install the secrets into place:

```sh
ssh -t joshan@192.168.1.3 '
  sudo install -d -m 700 /root/secrets &&
  sudo cp -a /tmp/nixos-server-secrets/. /root/secrets/ &&
  sudo chown -R root:root /root/secrets &&
  sudo chmod 600 /root/secrets/*
'
```

Install the GitHub SSH key for the `joshan` user so the Pi can pull the private repo later:

```sh
ssh -t joshan@192.168.1.3 '
  sudo install -d -m 700 -o joshan -g users /home/joshan/.ssh &&
  sudo install -m 600 -o joshan -g users /root/secrets/id_ed25519 /home/joshan/.ssh/id_ed25519 &&
  sudo install -m 644 -o joshan -g users /root/secrets/id_ed25519.pub /home/joshan/.ssh/id_ed25519.pub &&
  sudo -u joshan ssh-keyscan github.com > /tmp/github-known-hosts &&
  sudo install -m 644 -o joshan -g users /tmp/github-known-hosts /home/joshan/.ssh/known_hosts
'
```

## Restore Mutable App Data

Stop the hosted apps, restore the data directories, then rebuild:

```sh
ssh -t joshan@192.168.1.3 '
  sudo systemctl stop \
    docker-home-assistant.service \
    docker-adguard.service \
    docker-matter-server.service \
    docker-n8n.service \
    docker-openclaw.service 2>/dev/null || true &&
  sudo cp -a /tmp/ha-backup/homeassistant/data/. /var/lib/home-assistant/ &&
  sudo cp -a /tmp/ha-backup/a0d7b954_adguard/data/adguard/. /var/lib/adguard/conf/ &&
  sudo cp -a /tmp/ha-backup/core_matter_server/data/. /var/lib/matter-server/ &&
  sudo cp -a /tmp/ha-backup/3cfc8f0f_hass-n8n/data/n8n/.n8n/. /var/lib/n8n/ &&
  sudo nixos-rebuild switch --flake /home/joshan/.files#nixos-server
'
```

`/var/lib/adguard/work` is not restored from the Home Assistant backup.
AdGuard recreates it. The AdGuard macvlan parent interface is detected from the default IPv4 route at runtime, so the install does not depend on the Ethernet interface being named `end0`.

OpenClaw starts fresh unless you deliberately restore old state later.

## Verify The System

Run these checks on the Pi:

```sh
sudo systemctl --no-pager --full status \
  docker-home-assistant.service \
  docker-adguard.service \
  docker-matter-server.service \
  docker-n8n.service \
  docker-openclaw.service \
  tailscaled.service \
  restic-backups-home-assistant.timer
```

Check the main endpoints from the user's machine:

```sh
curl -I http://192.168.1.3:8123
curl -I http://192.168.1.2:3000
curl -I http://192.168.1.3:5678
```

## Updating Later

For normal system updates on the Pi:

```sh
cd /home/joshan/.files &&
  git pull --recurse-submodules &&
  sudo nixos-rebuild switch --flake .#nixos-server
```

For app config changes managed outside Nix:

- Home Assistant config lives in `/var/lib/home-assistant`
- AdGuard config lives in `/var/lib/adguard/conf`
- Matter Server data lives in `/var/lib/matter-server`
- `n8n` data lives in `/var/lib/n8n`
- OpenClaw state lives in `/var/lib/openclaw`
- OpenClaw auth profile state lives in `/var/lib/openclaw-auth`

Those paths are covered by Snapper snapshots and the restic Dropbox backup.
