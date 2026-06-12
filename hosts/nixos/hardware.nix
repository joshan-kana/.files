{ lib, ... }:

{
  # Host hardware can be regenerated into this file with nixos-generate-config.
  # The previous flake imported /etc/nixos/hardware-configuration.nix directly,
  # which prevents pure flake evaluation outside the installed host.
  fileSystems."/" = lib.mkDefault {
    device = "none";
    fsType = "tmpfs";
  };
}
