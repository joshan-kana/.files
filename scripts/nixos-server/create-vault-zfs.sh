#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  create-vault-zfs.sh --dry-run /dev/disk/by-id/DISK_A /dev/disk/by-id/DISK_B
  create-vault-zfs.sh --apply   /dev/disk/by-id/DISK_A /dev/disk/by-id/DISK_B

Creates the mirrored ZFS pool "vault" and datasets mounted under /srv/vault.
Apply mode destroys filesystem signatures on both disks. Use whole-disk
/dev/disk/by-id paths only; never use /dev/sdX paths.
EOF
}

mode="${1:-}"
disk_a="${2:-}"
disk_b="${3:-}"

case "$mode" in
  --dry-run | --apply) ;;
  -h | --help | "")
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [ -z "$disk_a" ] || [ -z "$disk_b" ] || [ -n "${4:-}" ]; then
  usage >&2
  exit 2
fi

if [ "$EUID" -ne 0 ]; then
  echo "ERROR: run this script with sudo so it can inspect disk signatures." >&2
  exit 1
fi

case "$disk_a:$disk_b" in
  /dev/disk/by-id/*:/dev/disk/by-id/*) ;;
  *)
    echo "ERROR: use stable /dev/disk/by-id/... paths only." >&2
    exit 1
    ;;
esac

for disk in "$disk_a" "$disk_b"; do
  if [ ! -b "$disk" ]; then
    echo "ERROR: not a block device: $disk" >&2
    exit 1
  fi
  if [ "$(lsblk -dnro TYPE "$disk")" != "disk" ]; then
    echo "ERROR: supply a whole disk, not a partition: $disk" >&2
    exit 1
  fi
done

real_a="$(readlink -f "$disk_a")"
real_b="$(readlink -f "$disk_b")"
if [ "$real_a" = "$real_b" ]; then
  echo "ERROR: both disk paths resolve to the same device: $real_a" >&2
  exit 1
fi

if ! modprobe zfs; then
  echo "ERROR: the ZFS kernel module is unavailable; reboot into the latest NixOS configuration before continuing." >&2
  exit 1
fi

if [ ! -c /dev/zfs ]; then
  echo "ERROR: /dev/zfs is unavailable after loading the ZFS kernel module." >&2
  exit 1
fi

if zpool list vault >/dev/null 2>&1; then
  echo "ERROR: zpool 'vault' already exists." >&2
  zpool status vault || true
  exit 1
fi

echo "━━━ Candidate disks"
lsblk -o NAME,PATH,SIZE,FSTYPE,FSVER,LABEL,MODEL,SERIAL,TRAN,MOUNTPOINTS "$disk_a" "$disk_b"

echo
echo "━━━ Existing filesystem signatures"
wipefs -n "$disk_a"
wipefs -n "$disk_b"

echo
echo "━━━ Mount checks"
for disk in "$disk_a" "$disk_b"; do
  if lsblk -nrpo MOUNTPOINTS "$disk" | grep -q '[^[:space:]]'; then
    echo "ERROR: $disk or one of its partitions is mounted:" >&2
    lsblk -o NAME,PATH,FSTYPE,LABEL,MOUNTPOINTS "$disk" >&2
    exit 1
  fi
done
echo "No mounts found on either supplied disk or its partitions."

echo
echo "━━━ Commands that will run in --apply mode"
cat <<EOF
wipefs -a "$disk_a"
wipefs -a "$disk_b"

zpool create \\
  -o ashift=12 \\
  -O mountpoint=none \\
  -O compression=lz4 \\
  -O atime=off \\
  -O xattr=sa \\
  -O acltype=posixacl \\
  vault mirror \\
  "$disk_a" \\
  "$disk_b"

zfs create -o mountpoint=/srv/vault vault/data
zfs create -o recordsize=1M vault/data/media
zfs create -o recordsize=1M vault/data/photos
zfs create vault/data/imports
zfs create vault/data/archive
zfs create vault/data/nextcloud
zfs create vault/data/documents
zfs create vault/data/shares
zfs create vault/data/backups
EOF

if [ "$mode" = "--dry-run" ]; then
  echo
  echo "DRY RUN ONLY. Nothing was changed."
  exit 0
fi

echo
echo "━━━ Final confirmation"
echo "This will erase filesystem signatures from:"
echo "  $disk_a"
echo "  $disk_b"
echo
read -r -p 'Type CREATE VAULT to continue: ' confirm
if [ "$confirm" != "CREATE VAULT" ]; then
  echo "Cancelled."
  exit 1
fi

echo
echo "━━━ Wiping signatures"
wipefs -a "$disk_a"
wipefs -a "$disk_b"

echo
echo "━━━ Creating ZFS mirror"
zpool create \
  -o ashift=12 \
  -O mountpoint=none \
  -O compression=lz4 \
  -O atime=off \
  -O xattr=sa \
  -O acltype=posixacl \
  vault mirror \
  "$disk_a" \
  "$disk_b"

echo
echo "━━━ Creating datasets"
zfs create -o mountpoint=/srv/vault vault/data
zfs create -o recordsize=1M vault/data/media
zfs create -o recordsize=1M vault/data/photos
zfs create vault/data/imports
zfs create vault/data/archive
zfs create vault/data/nextcloud
zfs create vault/data/documents
zfs create vault/data/shares
zfs create vault/data/backups

echo
echo "━━━ Creating expected folders"
mkdir -p \
  /srv/vault/archive/lacie-rescue \
  /srv/vault/imports/dropbox-test \
  /srv/vault/media/library \
  /srv/vault/media/downloads \
  /srv/vault/media/transcode
chgrp -R server-data /srv/vault
find /srv/vault -type d -exec chmod 2775 {} +

echo
echo "━━━ Result"
zpool status vault
zfs list -r vault
