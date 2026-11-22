{
  editScope,
  extendScope,
  lib,
  moduleRegistry,
  pkgs,
  ...
}:

lib.recursiveUpdate (import ../../profiles/workstation.nix { inherit moduleRegistry; }) {
  hardware = import ./hardware.nix;

  system = extendScope moduleRegistry.system {
    parallels = _: {
      systemd.user.services.prlcc.serviceConfig = {
        Restart = "on-failure";
        RestartSec = "2s";
      };

  networking = editScope moduleRegistry.networking {
    ssh = { config, ... }: {
      users.users.${config.dotfiles.users.primary.name}.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMZdbT05P/naiv07J32DxHDOR5A1z8F9jijeBrDkXWV joshankana@gmail.com"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJsiQZEG5WB92zEubOX4InNHN4ev8byz2KBwzGLzMWPA chatgpt-shell-nixos-arm-parallels"
      ];
    };
  };

  desktopApps = editScope moduleRegistry.desktopApps {
    kitty = _: {
      home = _: {
        programs.kitty.package = pkgs.kitty-virgl;
      };
    };
  };

  boot = {
    initrd.kernelModules = [ "virtio_gpu" ];
    kernelPackages = pkgs.linuxPackages_latest;
  };
}
