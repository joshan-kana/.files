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
- Btrfs subvolumes: `/var/lib/apps`
- Nix store path: `/nix/store`
- External Vault: ZFS mirror mounted at `/srv/vault` when the LaCie drives are connected

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
- a local checkout of this repo
- an `aarch64-linux` builder

This repo already has an OrbStack NixOS machine named `nixos`, so this guide
uses that as the builder through the `orb` SSH alias.

Set these variables on the user's machine:

```sh
export REPO_DIR="$HOME/.files"
export BUILD_HOST="orb"
```

## Backup Recovery Kit

Normal replacement installs do not need a manually maintained copy of every
runtime secret. The external recovery store keeps only the two bootstrap files
needed to reach the encrypted secrets repository:

```text
rclone.conf
secrets-restic-password
```

The recovery `rclone.conf` must contain a Dropbox remote named `dropbox`. Its
long-lived refresh token is the durable credential; the cached access token may
be expired. Rclone refreshes that access token when the config is used, so the
external recovery copy does not need to track normal token refreshes.

The secrets repository is:

```text
rclone:dropbox:Archives/Backups/secrets/nixos-server
```

It contains the current backed-up state of:

```text
/root/secrets
/home/joshan/.secrets
/var/lib/userborn
```

On a replacement machine, install the two recovery files under
`/var/lib/backup-credentials`, restore the secrets repository, then restore the
larger app-data repository. Do not maintain a second full plaintext secrets
bundle on another machine.

### First-time recovery-kit creation

This is only needed if no external recovery kit exists yet. Configure Dropbox
with a remote named exactly `dropbox`:

```sh
nix shell nixpkgs#rclone -c rclone config
```

Use browser authorization when prompted. Keep Full Dropbox access if the backup
repositories must remain under `Archives/Backups/`. Save a recovery copy of the
resulting `rclone.conf` in the external recovery store.

Generate a unique password for the `nixos-server` secrets repository and save
that password in the same external recovery kit. Do not reuse the application
data repository password.

For the one-time migration from an existing live server, install those two
bootstrap files locally, initialize `restic-secrets`, and take the first backup
as described in `backup-restore.md`. After that first snapshot, replacement
installs recover the runtime secret directories from Restic instead of manually
reconstructing them.

A truly new deployment with no previous secrets repository must create its
runtime credentials once before taking that first snapshot. That is initial
service provisioning, not part of the normal disaster-recovery path.

### First-time runtime-secret provisioning

For a genuinely new server with no secrets snapshot to restore, create
`/root/secrets` with mode `0700` and put the required service credentials there
before taking the first secrets backup. At minimum, preserve the existing
service-specific filenames expected by the NixOS configuration.

For Tailscale, configure the tailnet policy before creating the OAuth client:

```json
{
  "tagOwners": {
    "tag:nixos-server": [
      "autogroup:admin"
    ]
  },
  "autoApprovers": {
    "routes": {
      "192.168.1.0/24": [
        "tag:nixos-server"
      ]
    }
  }
}
```

In the Tailscale admin console, create an OAuth client with `auth_keys` and
`devices:core` write scopes, restrict it to `tag:nixos-server`, and install the
client ID and secret as:

```text
/root/secrets/tailscale-oauth-client-id
/root/secrets/tailscale-oauth-client-secret
```

`n8n.env` must contain a durable `N8N_ENCRYPTION_KEY`, and other enabled services
must have the runtime files required by their modules. Keep all files under
`/root/secrets` mode `0600`. Once the initial set is complete, take the first
`restic-secrets` snapshot; future replacement installs restore these files from
that repository instead of provisioning them again.

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

Verify Tailscale after the first rebuild or restore:

```sh
ssh joshan@192.168.1.3 '
  tailscale status --json --peers=false | jq "{
    host: .Self.HostName,
    dns: .Self.DNSName,
    ips: .Self.TailscaleIPs,
    online: .Self.Online
  }"
  tailscale debug prefs | grep -E "Hostname|AdvertiseRoutes|192\\.168\\.1\\.0" || true
'
```

If a previous `nixos-server` node is still visible in the Tailscale admin console
after a replacement, remove it manually from the web UI, then reboot the server.

Immediately change the temporary first-boot password:

```sh
passwd
```

## Copy Repo And Bootstrap Credentials

Copy the repository to the server. Retrieve the recovery `rclone.conf` and the
`nixos-server` secrets-repository password from the external recovery store into temporary local files first;
do not paste either value into shell history.

```sh
export SERVER="192.168.1.3"
export RECOVERY_RCLONE_CONFIG="/path/to/temporary/rclone.conf"
export SECRETS_RESTIC_PASSWORD_FILE="/path/to/temporary/secrets-restic-password"

ssh "joshan@$SERVER" 'mkdir -p /home/joshan/.files' &&
nix shell nixpkgs#rsync -c rsync -ah --delete --info=progress2 \
  --exclude /result \
  --exclude /.direnv \
  "$REPO_DIR"/ \
  "joshan@$SERVER:/home/joshan/.files/" &&
scp "$RECOVERY_RCLONE_CONFIG" "$SECRETS_RESTIC_PASSWORD_FILE" \
  "joshan@$SERVER:/tmp/" &&
ssh -t "joshan@$SERVER" '
  set -e
  sudo install -d -m 700 /var/lib/backup-credentials
  sudo install -m 600 -o root -g root /tmp/rclone.conf \
    /var/lib/backup-credentials/rclone.conf
  sudo install -m 600 -o root -g root /tmp/secrets-restic-password \
    /var/lib/backup-credentials/secrets-restic-password
  rm -f /tmp/rclone.conf /tmp/secrets-restic-password
'
```

Apply the system configuration so the `restic-secrets` wrapper is available:

```sh
ssh -t "joshan@$SERVER" \
  'sudo nixos-rebuild switch --flake /home/joshan/.files#nixos-server'
```

Verify the secret repository before changing live secret paths:

```sh
ssh -t "joshan@$SERVER" 'sudo restic-secrets snapshots'
```

For a replacement server, restore the latest secret snapshot directly to its
recorded absolute paths:

```sh
ssh -t "joshan@$SERVER" '
  sudo restic-secrets restore latest --target /

  sudo install -d -m 700 -o joshan -g users /home/joshan/.ssh
  sudo install -m 600 -o joshan -g users \
    /root/secrets/id_ed25519 /home/joshan/.ssh/id_ed25519
  sudo install -m 644 -o joshan -g users \
    /root/secrets/id_ed25519.pub /home/joshan/.ssh/id_ed25519.pub
'
```

For the first deployment of the secrets-backup scheme, initialize the empty
repository once instead of restoring it:

```sh
ssh -t "joshan@$SERVER" 'sudo restic-secrets init'
```

Then trigger the first backup and verify that a snapshot exists:

```sh
ssh -t "joshan@$SERVER" '
  sudo systemctl start restic-backups-secrets.service
  sudo restic-secrets snapshots
'
```

## Restore Mutable App Data

For a replacement NixOS server with an existing restic backup, restore the app
data root directly. The restic repository contains `/var/lib/apps`, so no app
names need to be listed here:

```sh
ssh -t "joshan@$SERVER" '
  sudo env RCLONE_CONFIG=/var/lib/backup-credentials/rclone.conf \
    restic -r rclone:dropbox:Archives/Backups/nixos-server \
    --password-file /root/secrets/restic-password \
    restore latest \
    --target / \
    --include /var/lib/apps

  sudo nixos-rebuild switch --flake /home/joshan/.files#nixos-server
'
```

For a one-time HAOS backup migration, use `docs/nixos-server/migration.md`.

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

From outside the LAN, keep Tailscale connected and use the same LAN URL
`http://192.168.1.3:8123`; access is provided by the approved subnet route.

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

The external Vault pool is restored separately after a full SD-card rebuild.
Follow [Vault ZFS Storage](vault-storage.md) to import and verify it; do not run
the destructive pool-creation step again. Vault data is locally snapshotted but
is not included in the app-data restic backup.
