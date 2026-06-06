# NixOS Server Install Guide

This guide is the install path for this server:

- Raspberry Pi 4 8 GB
- booting from a microSD card
- Ethernet during install
- headless access over SSH
- Home Assistant data restored from your exported backup

References:

- `https://wiki.nixos.org/wiki/NixOS_on_ARM/Raspberry_Pi_4`
- `https://nix.dev/tutorials/nixos/installing-nixos-on-a-raspberry-pi`
- `https://nixos.org/manual/nixos/stable/`

The 4 GB and 8 GB Raspberry Pi 4 models use the same installation method here.
The install flow, image type, boot process, and NixOS hardware support are the
same. The 8 GB model just has more RAM available after boot.

## Final Result

After the install is finished, this machine should look like this:

- NixOS host IP: `192.168.1.3`
- Home Assistant: `http://192.168.1.3:8123`
- AdGuard DNS IP: `192.168.1.2`
- repo path on the Pi: `/home/joshan/.files`
- app data root: `/var/lib`
- runtime secrets: `/root/secrets`

## Before You Start

You need:

- a Raspberry Pi 4
- a microSD card
- wired Ethernet to your LAN
- an SSH public key on the user's machine, usually `~/.ssh/id_ed25519.pub`
- your private repo or a local copy of the repo
- your exported Home Assistant backup in Downloads
- the bootstrap secrets you want to place in `/root/secrets`

Set these variables once at the start of the install session on the user's
machine and reuse them throughout the guide:

```sh
export REPO_DIR="$HOME/.files"
export HA_BACKUP_ARCHIVE="PATH_TO_HOME_ASSISTANT_BACKUP.tar"
export HA_BACKUP_DIR="$(dirname "$HA_BACKUP_ARCHIVE")/extracted-home-assistant-backup"
export SECRETS_DIR="PATH_TO_SECRETS_DIRECTORY"
```

Keep that terminal open while running the user's-machine commands. If you open
a new terminal later, re-run the variable block before using the copy or SSH
commands.

What they mean:

- `REPO_DIR`: the local checkout of this repo on the user's machine
- `HA_BACKUP_ARCHIVE`: the Home Assistant backup file downloaded from Home
  Assistant
- `HA_BACKUP_DIR`: the extracted contents of that backup file, next to the
  archive by default
- `SECRETS_DIR`: the local directory containing bootstrap secret files

`HA_BACKUP_ARCHIVE` is the path to the backup file itself. `HA_BACKUP_DIR` is
the extracted directory used by the restore commands in this guide. By default,
the extracted directory is created beside the archive as
`extracted-home-assistant-backup`.

Home Assistant's current official backup docs describe backups as encrypted,
compressed archive files stored locally in `/backup` by default. For this
migration flow, you should download the backup to the user's machine and
extract it before copying the contents to the Pi.

## What The Home Assistant Backup Must Contain

For this migration, create a manual backup in Home Assistant and include:

- Home Assistant settings
- the add-on or app data you want to migrate

For this stack, that means you should include at least:

- Home Assistant settings
- AdGuard Home data
- Matter Server data
- n8n data

Optional:

- OpenClaw data, only if you later decide to salvage anything from it
- `media` and `share`, if you want them preserved

The current Home Assistant docs recommend disabling `media` and `share` if you
want a smaller backup. That advice also fits this migration, because this repo
does not depend on those directories for the main restore path.

If you want the safest capture for a one-time migration, create a manual backup
and select everything. That gives you the most recovery options later, even if
this NixOS migration only restores a subset of it.

## Extract The Home Assistant Backup

Run this on the user's machine before the restore steps.

Create the extraction directory:

```sh
mkdir -p "$HA_BACKUP_DIR" &&
  tar -xf "$HA_BACKUP_ARCHIVE" -C "$HA_BACKUP_DIR"
```

This guide assumes the extracted backup directory is what gets copied to the
Pi.

## Bootstrap Secrets

The completed directory should contain:

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
# If secrets do not exist (first run only)
Run this only on the first install if the secrets bundle does not already
exist:

```sh
mkdir -p "$SECRETS_DIR" &&
  chmod 700 "$SECRETS_DIR" &&
  cp "$HOME/.ssh/id_ed25519" "$SECRETS_DIR/" &&
  cp "$HOME/.ssh/id_ed25519.pub" "$SECRETS_DIR/" &&
  openssl rand -base64 32 > "$SECRETS_DIR/restic-password" &&
  chmod 600 "$SECRETS_DIR/"* &&
  touch "$SECRETS_DIR/n8n.env" &&
  touch "$SECRETS_DIR/openclaw.env"
```

File contents:

- `restic-password`: one strong password used to unlock the restic repository
- `rclone.conf`: rclone config containing a Dropbox remote named `dropbox`
- `tailscale-authkey`: a Tailscale auth key for first boot
- `n8n.env`: runtime environment for n8n secrets such as the encryption key
- `openclaw.env`: optional OpenClaw gateway environment variables
  `NAME=value` format
- `id_ed25519`: the GitHub SSH private key copied from the user's machine
- `id_ed25519.pub`: the matching GitHub SSH public key

Useful creation notes:

- `rclone.conf` should come from `rclone config` after creating a Dropbox
  remote named `dropbox`
- `n8n.env` can start as an empty file, but durable n8n deployments should set
  the encryption key there before relying on stored credentials
- `openclaw.env` can be an empty file until OpenClaw needs environment
  variables

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

The file should contain only the auth key value.

Create and authorize the Dropbox rclone remote on the user's machine:

```sh
nix shell nixpkgs#rclone
rclone config
```

In the rclone prompts:

1. choose `n` for a new remote
2. name the remote exactly `dropbox`
3. choose Dropbox as the storage provider
4. allow browser authorization when prompted
5. finish and save the remote

Copy the finished rclone config into the secrets directory:

```sh
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

The NixOS config passes `n8n.env` and `openclaw.env` directly to the
corresponding services as environment files. Leave them empty until the
service needs runtime secrets. Add one variable per line when needed:

```text
NAME=value
ANOTHER_NAME=another-value
```

Before copying secrets to the Pi, verify the expected filenames exist:

```sh
ls -l "$SECRETS_DIR" &&
  test -f "$SECRETS_DIR/restic-password" &&
  test -f "$SECRETS_DIR/rclone.conf" &&
  test -f "$SECRETS_DIR/tailscale-authkey" &&
  test -f "$SECRETS_DIR/n8n.env" &&
  test -f "$SECRETS_DIR/openclaw.env" &&
  test -f "$SECRETS_DIR/id_ed25519" &&
  test -f "$SECRETS_DIR/id_ed25519.pub"
```

Keep this directory outside Git. It is bootstrap material for the server, not
repo state.

## Fast Path

Because the user's machine already has Nix installed, use it as the control
machine for the whole install.

That means:

- download and unpack the SD image from the user's machine
- run the repo preflight checks from the user's machine
- flash the SD card from the user's machine
- copy the repo, backup data, and secrets from the user's machine
- keep the Pi work limited to partitioning, mounting, `nixos-install`, and the
  first reboot

The user's machine is faster and more ergonomic than typing everything directly
on the Pi, so this guide assumes that pattern.

If you want evaluation and cache checks, use the companion test guide instead:
[`docs/nixos-server/testing.md`](./testing.md).

## Step 1: Download The NixOS SD Image

Run this on the user's machine.

Download the latest generic AArch64 NixOS SD image from Hydra.
Then download and unpack the latest successful image:

```sh
nix shell nixpkgs#curl nixpkgs#zstd
curl -fL \
  -o nixos-aarch64-sd-image.img.zst \
  https://hydra.nixos.org/job/nixos/unstable/nixos.sd_image.aarch64-linux/latest/download-by-type/file/sd-image &&
  unzstd -f nixos-aarch64-sd-image.img.zst
```

## Step 2: Flash The SD Card

Run this on the user's machine.

Choose one flashing method.

### CLI (fastest and automated)

List disks before inserting the SD card and note the devices that are already
present:

```sh
diskutil list
```

Insert the SD card, then list disks again and identify the new `diskN` device:

```sh
diskutil list
export DISK_N="N"
```

Use the script that matches the user's machine.

macOS:

```sh
export INSTALLER_PUBKEY="$HOME/.ssh/id_ed25519.pub"

test -n "${DISK_N:?DISK_N is not set}"
test -f ./nixos-aarch64-sd-image.img
test -f "$INSTALLER_PUBKEY"

docker run --rm --privileged \
  -v "$PWD:/work" \
  -v "$INSTALLER_PUBKEY:/tmp/id_ed25519.pub:ro" \
  ubuntu:24.04 \
  bash -euxc '
    apt-get update
    apt-get install -y e2fsprogs mount util-linux parted
    mkdir -p /mnt/nixos-sd
    root_offset="$(parted -sm /work/nixos-aarch64-sd-image.img unit B print | awk -F: '"'"'$1=="2"{gsub(/B/, "", $2); print $2}'"'"')"
    test -n "$root_offset"
    loop="$(losetup --find --show -o "$root_offset" /work/nixos-aarch64-sd-image.img)"
    cleanup() {
      umount /mnt/nixos-sd 2>/dev/null || true
      losetup -d "$loop" 2>/dev/null || true
    }
    trap cleanup EXIT

    mount "$loop" /mnt/nixos-sd

    install -d -m 700 -o 1000 -g 100 /mnt/nixos-sd/home/nixos/.ssh
    install -m 600 -o 1000 -g 100 /tmp/id_ed25519.pub /mnt/nixos-sd/home/nixos/.ssh/authorized_keys

    install -d -m 755 -o 0 -g 0 /mnt/nixos-sd/etc/ssh/authorized_keys.d
    install -m 644 -o 0 -g 0 /tmp/id_ed25519.pub /mnt/nixos-sd/etc/ssh/authorized_keys.d/nixos

    test -f /mnt/nixos-sd/home/nixos/.ssh/authorized_keys
    test -f /mnt/nixos-sd/etc/ssh/authorized_keys.d/nixos

    cmp -s /tmp/id_ed25519.pub /mnt/nixos-sd/home/nixos/.ssh/authorized_keys
    cmp -s /tmp/id_ed25519.pub /mnt/nixos-sd/etc/ssh/authorized_keys.d/nixos

    stat -c "%u:%g %a %n" /mnt/nixos-sd/home/nixos/.ssh
    stat -c "%u:%g %a %n" /mnt/nixos-sd/home/nixos/.ssh/authorized_keys
    stat -c "%u:%g %a %n" /mnt/nixos-sd/etc/ssh/authorized_keys.d
    stat -c "%u:%g %a %n" /mnt/nixos-sd/etc/ssh/authorized_keys.d/nixos

    echo "OK: installer public key is in both SSH key locations"

    sync
  ' &&
  diskutil unmountDisk "/dev/disk${DISK_N}" &&
  sudo dd if=./nixos-aarch64-sd-image.img of="/dev/rdisk${DISK_N}" bs=4m status=progress conv=sync &&
  sync &&
  diskutil eject "/dev/disk${DISK_N}"
```

Linux desktop:

```sh
export SD_DEV="/dev/sdX"
export INSTALLER_PUBKEY="$HOME/.ssh/id_ed25519.pub"
export ROOT_OFFSET="$(parted -sm nixos-aarch64-sd-image.img unit B print | awk -F: '$1=="2"{gsub(/B/, "", $2); print $2}')"
test -n "$ROOT_OFFSET" &&
LOOP_DEV="$(sudo losetup --find --show -o "$ROOT_OFFSET" nixos-aarch64-sd-image.img)" &&
sudo mount "$LOOP_DEV" /mnt &&
  sudo install -d -m 700 -o 1000 -g 100 /mnt/home/nixos/.ssh &&
  sudo install -m 600 -o 1000 -g 100 "$INSTALLER_PUBKEY" /mnt/home/nixos/.ssh/authorized_keys &&
  sudo umount /mnt &&
  sudo losetup -d "$LOOP_DEV" &&
  sudo dd if=./nixos-aarch64-sd-image.img of="$SD_DEV" bs=4M conv=fsync status=progress
```

The installer key must end up at `/home/nixos/.ssh/authorized_keys`.
On macOS, the `FIRMWARE` partition is not that location.

### Raspberry Pi Imager

Choose `Use custom`, select `nixos-aarch64-sd-image.img`, choose the SD card,
and write the image.

### Balena Etcher

Select `nixos-aarch64-sd-image.img`, select the SD card, and flash it.

Do not choose a Raspberry Pi OS image. The Pi 4 wiki explicitly says the Pi 4B
works with the generic NixOS SD image.

With the image pre-seeded, the installer should accept the same public key on
first boot.

## Step 3: Boot The Pi

Do this on the Pi.

1. Insert the SD card.
2. Connect Ethernet.
3. Connect power.
4. Wait for the board to boot.

If you use a temporary screen, the Raspberry Pi 4 wiki notes that the login
prompt may appear on the second HDMI port even if boot logs appeared on the
first.

## Step 4: Find The Pi On The Network

Run this on the user's machine.

On first boot, the installer image should come up on a temporary DHCP address,
not yet on the final static address from this repo.

Find it using one of these methods:

1. your router's DHCP lease table
2. `nmap` from the user's machine
3. `arp` from the user's machine

Router method:

Open the router admin page and look for a new DHCP lease on the wired LAN. The
device name may appear as `nixos`, `nixos-installer`, or an unnamed Ethernet
client.

Network scan method:

```sh
export PI_INSTALL_IP="$(
  nix shell nixpkgs#nmap -c sh -c '
    nmap -p 22 --open 192.168.1.0/24
  ' | awk '
    /Nmap scan report for/ {
      host = $NF
      gsub(/[()]/, "", host)
    }

    /22\/tcp open/ {
      print host
    }
  ' | while read -r host; do
    ssh-keygen -R "$host" >/dev/null 2>&1 || true

    if ssh \
      -i "$HOME/.ssh/id_ed25519" \
      -o IdentitiesOnly=yes \
      -o PreferredAuthentications=publickey \
      -o BatchMode=yes \
      -o ConnectTimeout=5 \
      -o StrictHostKeyChecking=accept-new \
      nixos@"$host" true 2>/dev/null; then
        printf "%s\n" "$host"
        exit 0
    fi
  done
)"

printf 'PI_INSTALL_IP=%s\n' "$PI_INSTALL_IP"
test -n "$PI_INSTALL_IP"

ssh \
  -i "$HOME/.ssh/id_ed25519" \
  -o IdentitiesOnly=yes \
  -o PreferredAuthentications=publickey \
  nixos@"$PI_INSTALL_IP" true
```

If that command does not return an address, check the router lease table or run
`arp -a` and set `PI_INSTALL_IP` manually.

If the SSH command exits successfully, key-based installer access is working.
If it prints `Permission denied` or falls back to a password prompt, re-run the
image key-seeding block in Step 2, re-flash the SD card, and boot again.

After a successful key-based SSH test, the wait loop is safe to use:

```sh
until ssh -o BatchMode=yes -o ConnectTimeout=5 nixos@"$PI_INSTALL_IP" true; do
  sleep 10
done
```

If `ssh-keygen -R` reports that `~/.ssh/known_hosts` is invalid, clean the bad
lines first or move the broken file aside before retrying.

Keep `PI_INSTALL_IP` in the same terminal used for the later `rsync` and `scp`
commands. If the terminal closes, re-export it before continuing.

## Step 5: Copy The Repo And Home Assistant Backup To The Installer

Run this on the user's machine.

Only copy what the installer needs to build the target system:

```sh
rsync -a --exclude .git "$REPO_DIR"/ nixos@"$PI_INSTALL_IP":/home/nixos/nixos-server/
rsync -a "$HA_BACKUP_DIR"/ nixos@"$PI_INSTALL_IP":/home/nixos/ha-backup/
ssh -t nixos@"$PI_INSTALL_IP" 'sudo -i'
```

## Step 6: Partition The Target Disk And Install NixOS

Run this in the installer shell on the Pi.

```sh
# Detect the SD card and set install variables.
export DISK_DEV="$(
  lsblk -dpno NAME,TRAN,TYPE | awk '$2 == "mmc" && $3 == "disk" { print $1; exit }'
)"
test -n "$DISK_DEV"
export INSTALL_DOTFILES=/mnt/home/joshan/.files
export FLK_PROFILE=nixos-server

# Inspect the target disk.
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL
printf 'Using SD disk: %s\n' "$DISK_DEV"

# Partition and format the SD card.
parted "$DISK_DEV" -- mklabel gpt
parted "$DISK_DEV" -- mkpart primary fat32 1MiB 512MiB
parted "$DISK_DEV" -- set 1 esp on
parted "$DISK_DEV" -- name 1 FIRMWARE
parted "$DISK_DEV" -- mkpart primary btrfs 512MiB 100%
parted "$DISK_DEV" -- name 2 NIXOS
mkfs.fat -F 32 -n FIRMWARE "${DISK_DEV}p1"
mkfs.btrfs -f -L NIXOS "${DISK_DEV}p2"

# Create and mount the target layout.
mount /dev/disk/by-label/NIXOS /mnt
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/var-lib
umount /mnt
mount -o compress=zstd,subvol=root /dev/disk/by-label/NIXOS /mnt
mkdir -p /mnt/boot /mnt/var/lib /mnt/home/joshan
mount /dev/disk/by-label/FIRMWARE /mnt/boot
mount -o compress=zstd,subvol=var-lib /dev/disk/by-label/NIXOS /mnt/var/lib

# Generate the base hardware config and stage the repo.
nixos-generate-config --root /mnt
cp -a /home/nixos/nixos-server/. /mnt/home/joshan/.files

# Install the system and reboot into the final host.
nixos-install --flake "$INSTALL_DOTFILES#$FLK_PROFILE"
reboot
```

## Step 7: Reconnect To The Final System

After reboot, connect from the user's machine:

```sh
ssh joshan@192.168.1.3
```

This host now uses the final static address from the repo. If SSH fails, check
the router lease or static table and inspect `systemctl status sshd.service`
from a local console once.

## Step 8: Copy Secrets And Mutable App Data

Run this on the user's machine after the final system is up.

```sh
rsync -a "$SECRETS_DIR"/ joshan@192.168.1.3:/tmp/nixos-server-secrets/
rsync -a "$HA_BACKUP_DIR"/ joshan@192.168.1.3:/tmp/ha-backup/
ssh -t joshan@192.168.1.3 'sudo -i'
```

Then run this on the Pi:

```sh
install -d -m 700 /root/secrets
install -m 400 /tmp/nixos-server-secrets/restic-password /root/secrets/restic-password
install -m 400 /tmp/nixos-server-secrets/rclone.conf /root/secrets/rclone.conf
install -m 400 /tmp/nixos-server-secrets/tailscale-authkey /root/secrets/tailscale-authkey
install -m 400 /tmp/nixos-server-secrets/n8n.env /root/secrets/n8n.env
install -m 400 /tmp/nixos-server-secrets/openclaw.env /root/secrets/openclaw.env

install -d -m 700 /home/joshan/.ssh
install -m 600 /tmp/nixos-server-secrets/id_ed25519 /home/joshan/.ssh/id_ed25519
install -m 644 /tmp/nixos-server-secrets/id_ed25519.pub /home/joshan/.ssh/id_ed25519.pub
cat > /home/joshan/.ssh/config <<'EOF'
Host github.com
  HostName ssh.github.com
  Port 443
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
EOF
chmod 600 /home/joshan/.ssh/config
chown -R joshan:users /home/joshan/.ssh

install -d -m 750 /var/lib/home-assistant
rsync -a /tmp/ha-backup/data/homeassistant/ /var/lib/home-assistant/
```

If you are restoring more add-on data from the backup, copy only the service
directories you intend to keep into the matching `/var/lib/...` locations.
Leave services you want to rebuild from scratch alone.

## Step 9: Re-apply The Current Config

Run this on the Pi.

```sh
export DOTFILES=/home/joshan/.files
export FLK_PROFILE=nixos-server
export NIXOS_REBUILD_FLAGS=
cd "$DOTFILES"
git submodule update --init --recursive
sudo nixos-rebuild $NIXOS_REBUILD_FLAGS switch --flake .#$FLK_PROFILE
```

## Step 10: Verify Services

Run this on the Pi.

```sh
systemctl status docker-home-assistant.service
systemctl status docker-adguard.service
systemctl status docker-matter-server.service
systemctl status n8n.service
systemctl status tailscaled.service
systemctl list-timers 'restic*'
sudo ls -l /root/secrets
```

Then verify from the user's machine:

1. open `http://192.168.1.3:8123`
2. verify AdGuard responds on `192.168.1.2`
3. confirm a client can use `192.168.1.2` as DNS

## Step 11: What Lives Where

System configuration:

- `/home/joshan/.files`

Mutable app data:

- `/var/lib/home-assistant`
- `/var/lib/adguard`
- `/var/lib/matter-server`
- `/var/lib/n8n`
- `/var/lib/openclaw`
- `/var/lib/tailscale`

Runtime secrets:

- `/root/secrets/restic-password`
- `/root/secrets/rclone.conf`
- `/root/secrets/tailscale-authkey`
- `/root/secrets/n8n.env`
- `/root/secrets/openclaw.env`

## Step 12: Update Later

Use Git for NixOS config updates:

```sh
cd /home/joshan/.files
git pull
git submodule update --init --recursive
sudo nixos-rebuild switch --flake .#nixos-server
```

Edit mutable app data directly under `/var/lib/...` when the app owns the
state. Restic and Snapper cover that data, while Nix and Git cover the system
configuration.
