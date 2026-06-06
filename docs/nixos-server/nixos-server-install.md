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
- `tailscale-authkey` should contain a real auth key from the Tailscale admin
  console
- `n8n.env` can start as an empty file, but durable n8n deployments should set
  the encryption key there before relying on stored credentials
- `openclaw.env` can be an empty file until OpenClaw needs environment
  variables

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

## Step 2: Flash The SD Card And Prepare SSH

Run this on the user's machine.

Choose one flashing method.

### CLI (fastest and automated)

Pick the SD card device, write the image, put your SSH public key onto the
installer volume, and eject the card:

```sh
diskutil list
export DISK_N="$(diskutil list | sed -n 's#^/dev/disk\([0-9][0-9]*\).*$#\1#p' | fzf)"
diskutil unmountDisk "/dev/disk${DISK_N}"
sudo dd if=./nixos-aarch64-sd-image.img of="/dev/rdisk${DISK_N}" bs=4m status=progress conv=sync
export NIXOS_SD_VOL="$(diskutil info "/dev/disk${DISK_N}" | awk -F': *' '/Volume Name/ {print $2; exit}')"
install -d -m 700 "/Volumes/$NIXOS_SD_VOL/home/nixos/.ssh"
cat ~/.ssh/id_ed25519.pub > "/Volumes/$NIXOS_SD_VOL/home/nixos/.ssh/authorized_keys"
chmod 600 "/Volumes/$NIXOS_SD_VOL/home/nixos/.ssh/authorized_keys"
diskutil eject "/dev/disk${DISK_N}"
```

### Raspberry Pi Imager

Choose `Use custom`, select `nixos-aarch64-sd-image.img`, choose the SD card,
and write the image.

### Balena Etcher

Select `nixos-aarch64-sd-image.img`, select the SD card, and flash it.

Do not choose a Raspberry Pi OS image. The Pi 4 wiki explicitly says the Pi 4B
works with the generic NixOS SD image.

If you cannot access the writable partition from the user's machine, boot once
with a temporary keyboard and screen, log in as `nixos`, and set a password
with:

```sh
passwd nixos
```

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
PI_INSTALL_IP="$(
  nix shell nixpkgs#nmap -c sh -c '
    nmap -sn 192.168.1.0/24 >/tmp/nmap-ping.txt
    nmap -p 22 --open 192.168.1.0/24 >/tmp/nmap-ssh.txt
    cat /tmp/nmap-ping.txt /tmp/nmap-ssh.txt
  ' | awk '
    /Nmap scan report for/ { host = $5 }
    /Discovered open port 22/ { print host; exit }
  '
)"
ssh-keygen -R "$PI_INSTALL_IP"
until ssh -o BatchMode=yes -o ConnectTimeout=5 nixos@"$PI_INSTALL_IP" true; do
  sleep 10
done
export PI_INSTALL_IP
```

If that script does not return an address, check the router lease table or run
`arp -a` and set `PI_INSTALL_IP` manually.

Keep `PI_INSTALL_IP` in the same terminal used for the later `rsync` and `scp`
commands. If the terminal closes, re-export it before continuing.

## Step 5: SSH Into The Installer And Run The Bootstrap

Run this on the user's machine.

User machine:

```sh
rsync -a --exclude .git "$REPO_DIR"/ nixos@"$PI_INSTALL_IP":/home/nixos/nixos-server/
rsync -a "$HA_BACKUP_DIR"/ nixos@"$PI_INSTALL_IP":/home/nixos/ha-backup/
rsync -a "$SECRETS_DIR"/ nixos@"$PI_INSTALL_IP":/home/nixos/nixos-server-secrets/
ssh -t nixos@"$PI_INSTALL_IP" 'sudo -i'
```

Once connected, you can paste this into the ssh to bootstrap the server:

```sh
# Detect the SD card and set install variables.
export DISK_DEV="$(
  lsblk -dpno NAME,TRAN,TYPE | awk '$2 == "mmc" && $3 == "disk" { print $1; exit }'
)"
test -n "$DISK_DEV"
export INSTALL_DOTFILES=/mnt/home/joshan/.files
export DOTFILES=/home/joshan/.files
export FLK_PROFILE=nixos-server
export NIXOS_REBUILD_FLAGS=

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
mkdir -p /mnt/boot /mnt/var/lib
mount /dev/disk/by-label/FIRMWARE /mnt/boot
mount -o compress=zstd,subvol=var-lib /dev/disk/by-label/NIXOS /mnt/var/lib

# Generate the base hardware config for validation.
nixos-generate-config --root /mnt

# Copy the repo and restored mutable data into place.
mkdir -p /mnt/home/joshan
cp -a /home/nixos/nixos-server/. /mnt/home/joshan/.files
rsync -a /home/nixos/ha-backup/ /mnt/home/joshan/ha-backup/

# Install bootstrap secrets.
install -d -m 700 /mnt/root/secrets
install -m 400 /home/nixos/nixos-server-secrets/restic-password /mnt/root/secrets/restic-password
install -m 400 /home/nixos/nixos-server-secrets/rclone.conf /mnt/root/secrets/rclone.conf
install -m 400 /home/nixos/nixos-server-secrets/tailscale-authkey /mnt/root/secrets/tailscale-authkey
install -m 400 /home/nixos/nixos-server-secrets/n8n.env /mnt/root/secrets/n8n.env
install -m 400 /home/nixos/nixos-server-secrets/openclaw.env /mnt/root/secrets/openclaw.env

# Install the GitHub SSH key pair for Pi access and repo pulls.
install -d -m 700 /mnt/home/joshan/.ssh
install -m 600 /home/nixos/nixos-server-secrets/id_ed25519 /mnt/home/joshan/.ssh/id_ed25519
install -m 644 /home/nixos/nixos-server-secrets/id_ed25519.pub /mnt/home/joshan/.ssh/id_ed25519.pub
cat > /mnt/home/joshan/.ssh/config <<'EOF'
Host github.com
  HostName ssh.github.com
  Port 443
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
EOF
chmod 600 /mnt/home/joshan/.ssh/config
chown -R 1000:100 /mnt/home/joshan/.ssh

# Install and reboot into the new system.
nixos-install --flake "$INSTALL_DOTFILES#$FLK_PROFILE"
reboot
```

## Step 6: Boot The Pi

Do this on the Pi.

1. Insert the SD card.
2. Connect Ethernet.
3. Connect power.
4. Wait for the board to boot.

If you use a temporary screen, the Raspberry Pi 4 wiki notes that the login
prompt may appear on the second HDMI port even if boot logs appeared on the
first.

## Step 7: Find The Pi On The Network

Run this on the user's machine.

Use the router lease table, or run the discovery block below if you prefer a
terminal check:

```sh
PI_INSTALL_IP="$(
  nix shell nixpkgs#nmap -c sh -c '
    nmap -sn 192.168.1.0/24 >/tmp/nmap-ping.txt
    nmap -p 22 --open 192.168.1.0/24 >/tmp/nmap-ssh.txt
    cat /tmp/nmap-ping.txt /tmp/nmap-ssh.txt
  ' | awk '
    /Nmap scan report for/ { host = $5 }
    /Discovered open port 22/ { print host; exit }
  '
)"
ssh-keygen -R "$PI_INSTALL_IP"
until ssh -o BatchMode=yes -o ConnectTimeout=5 nixos@"$PI_INSTALL_IP" true; do
  sleep 10
done
export PI_INSTALL_IP
```

## Step 8: Enter The Installer

Run this on the user's machine.

```sh
ssh nixos@"$PI_INSTALL_IP"
```

If you reach the installer with the key you copied earlier, no password should
be needed. Once connected, switch to root:

```sh
sudo -i
```

## Step 9: Finish The Target Disk

Run this on the Pi.

```sh
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL
export DISK_DEV="$(
  lsblk -dpno NAME,TRAN,TYPE | awk '$2 == "mmc" && $3 == "disk" { print $1; exit }'
)"
test -n "$DISK_DEV"
printf 'Using SD disk: %s\n' "$DISK_DEV"

parted "$DISK_DEV" -- mklabel gpt
parted "$DISK_DEV" -- mkpart primary fat32 1MiB 512MiB
parted "$DISK_DEV" -- set 1 esp on
parted "$DISK_DEV" -- name 1 FIRMWARE
parted "$DISK_DEV" -- mkpart primary btrfs 512MiB 100%
parted "$DISK_DEV" -- name 2 NIXOS
mkfs.fat -F 32 -n FIRMWARE "${DISK_DEV}p1"
mkfs.btrfs -f -L NIXOS "${DISK_DEV}p2"
mount /dev/disk/by-label/NIXOS /mnt
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/var-lib
umount /mnt
mount -o compress=zstd,subvol=root /dev/disk/by-label/NIXOS /mnt
mkdir -p /mnt/boot /mnt/var/lib
mount /dev/disk/by-label/FIRMWARE /mnt/boot
mount -o compress=zstd,subvol=var-lib /dev/disk/by-label/NIXOS /mnt/var/lib
nixos-generate-config --root /mnt
```

## Step 10: Copy The Repo And Data

Run this on the user's machine first.

```sh
rsync -a --exclude .git "$REPO_DIR"/ nixos@"$PI_INSTALL_IP":/home/nixos/nixos-server/
rsync -a "$HA_BACKUP_DIR"/ nixos@"$PI_INSTALL_IP":/home/nixos/ha-backup/
rsync -a "$SECRETS_DIR"/ nixos@"$PI_INSTALL_IP":/home/nixos/nixos-server-secrets/
```

Then on the Pi:

```sh
mkdir -p /mnt/home/joshan
cp -a /home/nixos/nixos-server/. /mnt/home/joshan/.files
rsync -a /home/nixos/ha-backup/ /mnt/home/joshan/ha-backup/
install -d -m 700 /mnt/root/secrets
install -m 400 /home/nixos/nixos-server-secrets/restic-password /mnt/root/secrets/restic-password
install -m 400 /home/nixos/nixos-server-secrets/rclone.conf /mnt/root/secrets/rclone.conf
install -m 400 /home/nixos/nixos-server-secrets/tailscale-authkey /mnt/root/secrets/tailscale-authkey
install -m 400 /home/nixos/nixos-server-secrets/n8n.env /mnt/root/secrets/n8n.env
install -m 400 /home/nixos/nixos-server-secrets/openclaw.env /mnt/root/secrets/openclaw.env
install -d -m 700 /mnt/home/joshan/.ssh
install -m 600 /home/nixos/nixos-server-secrets/id_ed25519 /mnt/home/joshan/.ssh/id_ed25519
install -m 644 /home/nixos/nixos-server-secrets/id_ed25519.pub /mnt/home/joshan/.ssh/id_ed25519.pub
cat > /mnt/home/joshan/.ssh/config <<'EOF'
Host github.com
  HostName ssh.github.com
  Port 443
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
EOF
chmod 600 /mnt/home/joshan/.ssh/config
chown -R 1000:100 /mnt/home/joshan/.ssh
```

## Step 11: Install The System

Run this on the Pi.

```sh
nixos-install --flake "$INSTALL_DOTFILES#$FLK_PROFILE"
reboot
```

## Step 12: Reconnect

After reboot, connect from the user's machine:

```sh
ssh joshan@192.168.1.3
```

If `ping` fails, check the router lease/static table. If SSH fails, use a local
console once and inspect `systemctl status sshd.service`.

## Step 13: First Login Fixups

Run this on the Pi after the real system is up.

```sh
sudo passwd joshan
ls /home/joshan/.files
sudo ls -l /root/secrets
```

## Step 14: Re-apply The Current Config

Run this on the Pi.

```sh
cd "$DOTFILES"
git pull
git submodule update --init --recursive
sudo nixos-rebuild $NIXOS_REBUILD_FLAGS switch --flake .#$FLK_PROFILE
```

## Step 15: Verify Services

Run this on the Pi.

```sh
systemctl status docker-home-assistant.service
systemctl status docker-adguard.service
systemctl status docker-matter-server.service
systemctl status n8n.service
systemctl status tailscaled.service
systemctl list-timers 'restic*'
```

Then verify from the user's machine:

1. open `http://192.168.1.3:8123`
2. verify AdGuard responds on `192.168.1.2`
3. confirm a client can use `192.168.1.2` as DNS

## Step 16: What Lives Where

System configuration:

- `/home/joshan/.files`

Mutable app data:

- `/var/lib/home-assistant`
- `/var/lib/adguard`
- `/var/lib/matter-server`
- `/var/lib/n8n`
- `/var/lib/openclaw`
- `/var/lib/tailscale`

Bootstrap secrets:

- `/root/secrets/restic-password`
- `/root/secrets/rclone.conf`
- `/root/secrets/tailscale-authkey`
- `/root/secrets/n8n.env`
- `/root/secrets/openclaw.env`

## Step 17: Update Later

Use Git for NixOS config updates:

```sh
cd /home/joshan/.files
git pull
sudo nixos-rebuild $NIXOS_REBUILD_FLAGS switch --flake .#$FLK_PROFILE
```

Edit mutable app data directly under `/var/lib/...` when the app owns the
state. Restic and Snapper cover that data, while Nix/Git cover the system
configuration.
If you cloned the repo without submodules, run `git submodule update --init --recursive`
before using links into `docs/infrastructure-docs`.
