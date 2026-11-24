{
  editScope,
  lib,
  moduleRegistry,
  ...
}:

lib.recursiveUpdate (import ../../profiles/workstation.nix { inherit moduleRegistry; }) {
  hardware = import ./hardware.nix;

  dotfiles.scopes = {
    system.boot.loader.enable = false;
    virtualisation.enable = false;

    desktopApps = {
      children.enable = false;
      bitwarden.enable = true;
      filelight.enable = true;
      gparted.enable = true;
      jellyfin.enable = true;
      kitty.enable = true;
      moonlight.enable = true;
      mopidy.enable = true;
      mullvad.enable = true;
      nautilus.enable = true;
      qbittorrent.enable = true;
      spotify.enable = true;
      vlc.enable = true;
      vscode.enable = true;
      zen.enable = true;
    };
  };

  theme = editScope moduleRegistry.theme {
    home = _: {
      stylix.targets.qt.enable = lib.mkForce false;
    };
  };

  system = editScope moduleRegistry.system {
    identity = { config, ... }: {
      users.users.${config.dotfiles.users.primary.name}.uid = 1000;
    };
    privilegeSshAgent = _: {
      environment.etc."elevation-authorized-key".text = ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEBfBg52XAZkpWk2cKNqvITRhsrnmEdz8yon5bpZZP/w joshan@nixos-pi-sudo
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMgQFxMmgs5HwY+l9twQBUEt672VOFrmgAnOKuoMuzz/ nixos-pi-sudo
      '';
    };
  };

  networking = editScope moduleRegistry.networking {
    ssh = { config, ... }: {
      users.users.${config.dotfiles.users.primary.name}.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMZdbT05P/naiv07J32DxHDOR5A1z8F9jijeBrDkXWV joshankana@gmail.com"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBU9mnHy1HP+StbXl3HmTSpOVJ1VETv9DYWUj1YmzDKc chatgpt-shell-nixos-pi"
      ];
    };
  };
}
