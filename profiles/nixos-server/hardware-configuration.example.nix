{ ... }:

{
  # Replace this file with the generated /etc/nixos/hardware-configuration.nix
  # from the target server before switching the nixos-server profile.
  #
  # Recommended layout for fast HA/app rollback:
  # - Btrfs root subvolume for the NixOS system.
  # - Separate Btrfs /var/lib subvolume for Home Assistant and container data.
  # - Snapper snapshots /var/lib only; Nix changes roll back through Git.
}
