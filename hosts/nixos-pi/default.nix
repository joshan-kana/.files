{
  config,
  editScope,
  lib,
  moduleRegistry,
  ...
}:

lib.recursiveUpdate (import ../../profiles/workstation.nix { inherit moduleRegistry; }) {
  hardware = import ./hardware.nix;

  # The Pi boots through firmware/U-Boot instead of an EFI boot manager.
  boot.loader = {
    grub.enable = false;
    generic-extlinux-compatible.enable = true;
  };

  dotfiles.scopes.system.boot.loader.enable = false;

  networking = editScope moduleRegistry.networking {
    ssh = _: {
      users.users.${config.dotfiles.users.primary.name}.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMZdbT05P/naiv07J32DxHDOR5A1z8F9jijeBrDkXWV joshankana@gmail.com"
      ];
    };
  };

  backups = editScope moduleRegistry.backups {
    secrets = { config, lib, ... }: {
      # The offline image has no user database. Set ownership once NixOS has
      # created the primary user, without assuming an allocation-specific UID.
      system.activationScripts.piSecretOwnership = {
        deps = [ "users" ];
        text = ''
          if [ -d ${lib.escapeShellArg "${config.dotfiles.users.primary.homeRoot}/${config.dotfiles.users.primary.name}"} ]; then
            chown ${lib.escapeShellArg config.dotfiles.users.primary.name}:users ${lib.escapeShellArg "${config.dotfiles.users.primary.homeRoot}/${config.dotfiles.users.primary.name}"}
          fi
          if [ -d ${lib.escapeShellArg config.dotfiles.secretsDir} ]; then
            chown -R ${lib.escapeShellArg config.dotfiles.users.primary.name}:users ${lib.escapeShellArg config.dotfiles.secretsDir}
          fi
        '';
      };
    };
  };
}
