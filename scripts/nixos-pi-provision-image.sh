#!/usr/bin/env bash
set -euo pipefail
umask 077

usage() {
  echo "Usage: $0 HOST_ENV.sh IMAGE.img SECRETS_DIR [BACKUP_CREDENTIALS_DIR]" >&2
  exit 2
}

(($# == 3 || $# == 4)) || usage
((EUID == 0)) || {
  echo 'Run this command as root on Linux.' >&2
  exit 1
}

[[ -r $1 ]] || {
  echo 'Missing generated host environment.' >&2
  exit 1
}
# This file is produced by the repository's evaluated runbook generator.
# shellcheck source=/dev/null
source "$1"

for variable in ROOT_DEVICE ROOT_FS PRIMARY_HOME USER_SECRETS_DIR SECRETS_RCLONE_CONFIG SECRETS_PASSWORD_FILE; do
  [[ -n ${!variable:-} ]] || {
    echo "Missing generated value: $variable" >&2
    exit 1
  }
done
for directory in PRIMARY_HOME USER_SECRETS_DIR SECRETS_RCLONE_CONFIG SECRETS_PASSWORD_FILE; do
  [[ ${!directory} == /* && ${!directory} != *'/../'* && ${!directory} != *'/./'* ]] || {
    echo "Invalid generated path: $directory" >&2
    exit 1
  }
done

image=$(realpath -- "$2")
secrets=$(realpath -- "$3")
backup=${4:+$(realpath -- "$4")}

[[ -f $image && -w $image && $image != /nix/store/* ]] || {
  echo 'Use a writable .img copy outside the Nix store.' >&2
  exit 1
}
[[ -d $secrets && -n $(find "$secrets" -type f -print -quit) ]] || {
  echo 'The host secrets source must contain at least one regular file.' >&2
  exit 1
}
if [[ -n $backup && (
  ! -f $backup/$(basename "$SECRETS_RCLONE_CONFIG") ||
  ! -f $backup/$(basename "$SECRETS_PASSWORD_FILE")) ]] \
  ; then
  echo 'Missing required backup bootstrap credentials.' >&2
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
root_partition=
for ((attempt = 0; attempt < 30; attempt++)); do
  for candidate in "${loop_device}"p*; do
    [[ -b $candidate ]] || continue
    if [[ $(blkid -s LABEL -o value "$candidate") == "${ROOT_DEVICE##*/}" ]]; then
      root_partition=$candidate
      break 2
    fi
  done
  sleep 0.2
done
[[ -n $root_partition && $(blkid -s TYPE -o value "$root_partition") == "$ROOT_FS" ]] || {
  echo 'Unexpected root partition label or filesystem; refusing to modify image.' >&2
  exit 1
}

mount -t "$ROOT_FS" "$root_partition" "$mount_dir"
mounted=true

# Home ownership is set by the host's declarative tmpfiles policy when the
# primary user is created. No UID needs to be pinned or guessed at image time.
install -d -m 0700 "$mount_dir$PRIMARY_HOME"
install -d -m 0700 "$mount_dir$USER_SECRETS_DIR"
cp -LR -- "$secrets/." "$mount_dir$USER_SECRETS_DIR/"
find "$mount_dir$USER_SECRETS_DIR" -type d -exec chmod 0700 {} +
find "$mount_dir$USER_SECRETS_DIR" -type f -exec chmod 0600 {} +

if [[ -n $backup ]]; then
  install -d -m 0700 "$(dirname "$mount_dir$SECRETS_RCLONE_CONFIG")"
  install -d -m 0700 "$(dirname "$mount_dir$SECRETS_PASSWORD_FILE")"
  install -m 0600 "$backup/$(basename "$SECRETS_RCLONE_CONFIG")" "$mount_dir$SECRETS_RCLONE_CONFIG"
  install -m 0600 "$backup/$(basename "$SECRETS_PASSWORD_FILE")" "$mount_dir$SECRETS_PASSWORD_FILE"
fi

sync
printf '%s\n' 'Credentials copied to their evaluated runtime paths.'
