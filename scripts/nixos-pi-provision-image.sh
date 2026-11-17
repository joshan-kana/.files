#!/usr/bin/env bash
set -euo pipefail
umask 077

usage() {
  echo "Usage: $0 IMAGE.img PI_SECRETS_DIR [BACKUP_CREDENTIALS_DIR]" >&2
  exit 2
}

(($# == 2 || $# == 3)) || usage
((EUID == 0)) || {
  echo 'Run as root on an ARM64 or x86_64 Linux machine.' >&2
  exit 1
}

for command in losetup mount umount blkid install mkpasswd realpath; do
  command -v "$command" >/dev/null || {
    echo "Missing program: $command" >&2
    exit 1
  }
done

image=$(realpath -- "$1")
secrets=$(realpath -- "$2")
backup=${3:+$(realpath -- "$3")}

[[ -f $image && -w $image && $image != /nix/store/* ]] || {
  echo 'Use a writable .img copy outside the Nix store.' >&2
  exit 1
}
[[ -f $secrets/comin-github ]] || {
  echo 'The Pi secrets directory must contain comin-github.' >&2
  exit 1
}
if [[ -n $backup && (! -f $backup/rclone.conf || ! -f $backup/secrets-restic-password) ]]; then
  echo 'Backup credentials must include rclone.conf and secrets-restic-password.' >&2
  exit 1
fi

mount_dir=$(mktemp -d)
loop_device=
mounted=false
cleanup() {
  if [[ $mounted == true ]]; then
    umount -- "$mount_dir"
  fi
  if [[ -n $loop_device ]]; then
    losetup -d -- "$loop_device"
  fi
  rmdir -- "$mount_dir"
}
trap cleanup EXIT

loop_device=$(losetup --find --show --partscan -- "$image")
root_partition="${loop_device}p2"
for ((attempt = 0; attempt < 30; attempt++)); do
  [[ -b $root_partition ]] && break
  sleep 0.2
done
[[ -b $root_partition ]] || {
  echo 'Root partition device is unavailable.' >&2
  exit 1
}
[[ $(blkid -s LABEL -o value "$root_partition") == NIXOS_SD &&
$(blkid -s TYPE -o value "$root_partition") == btrfs ]] || {
  echo 'Expected NIXOS_SD Btrfs as the second partition; refusing to modify image.' >&2
  exit 1
}

mount -t btrfs "$root_partition" "$mount_dir"
mounted=true

install -d -m 0700 -o 1000 -g 100 "$mount_dir/home/joshan/.secrets"
cp -LR -- "$secrets/." "$mount_dir/home/joshan/.secrets/"
chown -R 1000:100 "$mount_dir/home/joshan/.secrets"
find "$mount_dir/home/joshan/.secrets" -type d -exec chmod 0700 {} +
find "$mount_dir/home/joshan/.secrets" -type f -exec chmod 0600 {} +

if [[ -n $backup ]]; then
  install -d -m 0700 "$mount_dir/var/lib/backup-credentials"
  install -m 0600 "$backup/rclone.conf" "$mount_dir/var/lib/backup-credentials/rclone.conf"
  install -m 0600 "$backup/secrets-restic-password" "$mount_dir/var/lib/backup-credentials/secrets-restic-password"
fi

install -d -m 0700 "$mount_dir/var/lib/nixos-pi"
# mkpasswd prompts interactively and writes only a salted hash, never plaintext.
mkpasswd -m sha-512 >"$mount_dir/var/lib/nixos-pi/password-hash"
chmod 0600 "$mount_dir/var/lib/nixos-pi/password-hash"

sync
printf '%s\n' 'Provisioned Btrfs image at the final runtime paths.'
