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
- App data root: `/var/lib/apps`
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
- restored application data under `/var/lib/apps`

## Before You Start

You need:

- a Raspberry Pi 4
- a microSD card
- Power and Ethernet to the Pi
- the Home Assistant backup archive on the user's machine
- a local checkout of this repo
- an `aarch64-linux` builder

This repo already has an OrbStack NixOS machine named `nixos`, so this guide
uses that as the builder through the `orb` SSH alias.

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

Authorize Dropbox with rclone on the user's machine.

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

Create the Dropbox folder used by restic:

```sh
nix shell nixpkgs#rclone -c rclone mkdir dropbox:Archives/Backups/nixos-server
```

Test the remote:

```sh
nix shell nixpkgs#rclone -c rclone lsd dropbox:Archives/Backups
```

If the authorization has to be done for a headless machine, use rclone's remote
authorization flow from a machine with a browser:

```sh
nix shell nixpkgs#rclone -c rclone authorize dropbox
```

Paste the returned token into `rclone config` when it asks for remote
authorization, then copy the resulting `rclone.conf` into `SECRETS_DIR`.

`n8n.env` should at least contain a durable encryption key:

```text
N8N_ENCRYPTION_KEY=replace-this-with-a-long-random-value
```

## Build The SD Card Image

Build the image from macOS while executing the build inside the OrbStack NixOS
machine. The command points Nix at the repo path through OrbStack's macOS mount
and writes the `result` symlink back into the local checkout:

```sh
ssh "$BUILD_HOST" "nix build '/mnt/mac${REPO_DIR}#nixosConfigurations.nixos-server.config.system.build.image' -L --out-link '/mnt/mac${REPO_DIR}/result'"
```

The output is the full server image, not an installer image. The compressed
image can be used from the repo `result` symlink or copied to Downloads:

```sh
mkdir -p "$HOME/Downloads/nixos-server-image" &&
  cp -v "$(find -L "$REPO_DIR/result" -maxdepth 1 -type f -name '*.raw.zst' -print -quit)" \
    "$HOME/Downloads/nixos-server-image/"
```

Optional image sanity check on OrbStack before flashing:

```sh
ssh "$BUILD_HOST" '
  set -eu
  CHECK_DIR=/mnt/mac/Users/joshan/Downloads/nixos-server-image-check
  IMAGE_ZST="$(find -L /mnt/mac/Users/joshan/.files/result -maxdepth 1 -type f -name "*.raw.zst" -print -quit)"
  rm -rf "$CHECK_DIR" && mkdir -p "$CHECK_DIR"
  zstd -d -c "$IMAGE_ZST" > "$CHECK_DIR/nixos-server.raw"
  LOOP="$(sudo losetup --find --show --partscan "$CHECK_DIR/nixos-server.raw")"
  sudo mkdir -p "$CHECK_DIR/fw" "$CHECK_DIR/root"
  sudo mount "${LOOP}p1" "$CHECK_DIR/fw"
  sudo mount "${LOOP}p2" "$CHECK_DIR/root"
  INIT="$(grep -o "init=/nix/store/[^ ]*" "$CHECK_DIR/fw/extlinux/extlinux.conf" | cut -d= -f2)"
  test -d "$CHECK_DIR/root/nix/store"
  test -e "$CHECK_DIR/root$INIT"
  echo "image layout OK"
  sudo umount "$CHECK_DIR/root" "$CHECK_DIR/fw"
  sudo losetup -d "$LOOP"
'
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

Flash the compressed image directly. This block accepts either the repo `result`
symlink or a copied image in `~/Downloads/nixos-server-image`:

```sh
export IMAGE_ZST="$(
  find -L "$REPO_DIR/result" "$HOME/Downloads/nixos-server-image" \
    -type f -name '*.raw.zst' -print 2>/dev/null | head -n1
)"

test -n "${DISK_N:?DISK_N is not set}"
test -n "$IMAGE_ZST" || { echo "No .raw.zst image found; build the image first or set IMAGE_ZST manually." >&2; exit 1; }
test -f "$IMAGE_ZST"

echo "Image: $IMAGE_ZST"
diskutil info "/dev/disk${DISK_N}" | grep -E 'Device / Media Name|Disk Size|Total Size' || true

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

Copy the local repo to the server, copy the secrets bundle and the extracted
Home Assistant backup, then install the GitHub SSH key for authentication:

```sh
export SERVER="192.168.1.3"

ssh "joshan@$SERVER" '
  rm -rf /tmp/.secrets /tmp/ha-backup &&
  mkdir -p /tmp/.secrets /tmp/ha-backup /home/joshan/.files
' &&
  nix shell nixpkgs#rsync -c sh -eu -c '
    rsync -a --delete \
      --exclude /result \
      --exclude /.direnv \
      "$REPO_DIR"/ \
      "joshan@$SERVER:/home/joshan/.files/"

    rsync -a --delete \
      "$SECRETS_DIR"/ \
      "joshan@$SERVER:/tmp/.secrets/"

    rsync -a --delete \
      "$HA_BACKUP_DIR"/ \
      "joshan@$SERVER:/tmp/ha-backup/"
  ' &&
  ssh -t "joshan@$SERVER" '
    set -e

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

    rm -rf /tmp/.secrets /tmp/github-known-hosts
  '
```

## Restore App Data From Restic

Use this when replacing an existing NixOS server that already has a restic
backup. This restores the app data tree managed by the hosted containers:

```sh
ssh -t "joshan@$SERVER" '
  sudo env RCLONE_CONFIG=/root/secrets/rclone.conf \
    restic -r rclone:dropbox:Archives/Backups/nixos-server \
    --password-file /root/secrets/restic-password \
    restore latest \
    --target / \
    --include /var/lib/apps

  sudo nixos-rebuild switch --flake /home/joshan/.files#nixos-server
'
```

For the first HAOS to NixOS migration, use `migration.md` after the copy step.

## Verify The System

Run a short base-system check on the Pi:

```sh
ssh joshan@192.168.1.3 '
  hostname
  findmnt / /boot /var/lib
  systemctl is-system-running || true
  systemctl --failed --no-pager
'
```

Check the main endpoints from the user's machine after restore and rebuild:

```sh
curl -I http://192.168.1.3:8123
curl -I http://192.168.1.2:3000
curl -I http://192.168.1.3:5678
```

## Updating Later

For normal updates on the Pi, update flake inputs, commit the lock file, then
rebuild. The hosted containers are configured to restart when `flake.lock`
changes and to pull the current registry image for their configured tags:

```sh
cd /home/joshan/.files &&
  git pull --recurse-submodules &&
  nix flake update &&
  git add flake.lock &&
  git commit -m "chore: update flake inputs" &&
  sudo nixos-rebuild switch --flake .#nixos-server
```

For app config changes managed outside Nix, container app data lives under:

```text
/var/lib/apps/<app-name>
```

Those paths are covered by Snapper snapshots and the restic Dropbox backup.
