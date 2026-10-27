#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  create-vault-zfs.sh --dry-run /dev/disk/by-id/DISK_A /dev/disk/by-id/DISK_B
  create-vault-zfs.sh --apply   /dev/disk/by-id/DISK_A /dev/disk/by-id/DISK_B

Creates the configured mirrored ZFS pool and its data dataset.
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
  echo "ERROR: run this script as root so it can inspect disk signatures." >&2
  exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/../.." && pwd -P)"
flake_ref="path:${repo_root}"
nixos_config="nixosConfigurations.nixos-server.config"

if [ ! -f "$repo_root/flake.nix" ]; then
  echo "ERROR: could not find flake.nix at the expected repository root: $repo_root" >&2
  exit 1
fi

nix_value() {
  local option="$1"

  nix eval --raw "${flake_ref}#${nixos_config}.${option}"
}

pool_name="$(nix_value dotfiles.server.storage.dataRoot.poolName)"
data_root="$(nix_value dotfiles.server.storage.dataRoot.path)"
data_group="$(nix_value dotfiles.server.storage.dataRoot.group.name)"

if [ -z "$pool_name" ]; then
  echo "ERROR: Nix evaluated an empty ZFS pool name." >&2
  exit 1
fi

if [[ "$data_root" != /* ]] || [ "$data_root" = "/" ]; then
  echo "ERROR: unsafe data-root path evaluated from Nix: $data_root" >&2
  exit 1
fi

if [ -z "$data_group" ]; then
  echo "ERROR: Nix evaluated an empty data group." >&2
  exit 1
fi

if ! getent group "$data_group" >/dev/null; then
  echo "ERROR: configured data group does not exist: $data_group" >&2
  echo "Run the current NixOS configuration before creating the pool." >&2
  exit 1
fi

echo "━━━ Nix storage configuration"
printf 'Pool name:  %s\n' "$pool_name"
printf 'Mountpoint: %s\n' "$data_root"
printf 'Data group: %s\n' "$data_group"
echo

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

if zpool list "$pool_name" >/dev/null 2>&1; then
  echo "ERROR: zpool '$pool_name' is already imported." >&2
  zpool status "$pool_name" || true
  exit 1
fi

import_output="$(zpool import -d /dev/disk/by-id 2>/dev/null || true)"
if printf '%s\n' "$import_output" |
  awk -v pool="$pool_name" '
    $1 == "pool:" && $2 == pool {
      found = 1
    }

    END {
      exit found ? 0 : 1
    }
  '
then
  echo "ERROR: an existing importable pool named '$pool_name' was detected." >&2
  echo "Import the existing pool instead of running first-time setup." >&2
  exit 1
fi

echo "━━━ Candidate disks"
lsblk -o NAME,PATH,SIZE,FSTYPE,FSVER,LABEL,MODEL,SERIAL,TRAN,MOUNTPOINTS "$disk_a" "$disk_b"

echo
echo "━━━ Existing filesystem signatures"
for disk in "$disk_a" "$disk_b"; do
  while IFS= read -r device; do
    signatures="$(wipefs -n "$device")"
    printf '%s\n' "$signatures"

    if printf '%s\n' "$signatures" | grep -q 'zfs_member'; then
      echo "ERROR: existing ZFS metadata detected on $device (selected disk: $disk)." >&2
      echo "Refusing to overwrite a potentially recoverable pool member." >&2
      exit 1
    fi
  done < <(lsblk -nrpo PATH "$disk")
done

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
  "$pool_name" mirror \\
  "$disk_a" \\
  "$disk_b"

zfs create -o "mountpoint=$data_root" "${pool_name}/data"
chgrp -R "$data_group" "$data_root"
find "$data_root" -type d -exec chmod 2775 {} +
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
read -r -p "Type CREATE ${pool_name^^} to continue: " confirm
if [ "$confirm" != "CREATE ${pool_name^^}" ]; then
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
  "$pool_name" mirror \
  "$disk_a" \
  "$disk_b"

echo
echo "━━━ Creating data dataset"
zfs create -o "mountpoint=$data_root" "${pool_name}/data"

echo
echo "━━━ Setting dataset permissions"
chgrp -R "$data_group" "$data_root"
find "$data_root" -type d -exec chmod 2775 {} +

echo
echo "━━━ Result"
zpool status "$pool_name"
zfs list -r "$pool_name"
findmnt "$data_root"
