{
  editScope,
  lib,
  moduleRegistry,
  pkgs,
  ...
}:

lib.recursiveUpdate (import ../../profiles/workstation.nix { inherit moduleRegistry; }) {
  hardware = import ./hardware.nix;

  # Keep the test guest on the explicitly selected configuration revision.
  dotfiles.scopes = {
    system.autoDeploy.enable = false;
    networking.tailscaleClient.enable = false;
    virtualisation.children.enable = false;
  };

  networking = editScope moduleRegistry.networking {
    ssh = { config, ... }: {
      users.users.${config.dotfiles.users.primary.name}.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMZdbT05P/naiv07J32DxHDOR5A1z8F9jijeBrDkXWV joshankana@gmail.com"
      ];
    };
  };

  boot = {
    initrd.kernelModules = [ "virtio_gpu" ];
    kernelPackages = pkgs.linuxPackages_latest;
  };

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
  services.fstrim.enable = true;

  environment.systemPackages = with pkgs; [
    mesa-demos
    vulkan-tools
    wayland-utils
  ];
}
