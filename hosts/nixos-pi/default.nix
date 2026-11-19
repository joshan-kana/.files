{
  config,
  editScope,
  lib,
  moduleRegistry,
  ...
}:

lib.recursiveUpdate (import ../../profiles/workstation.nix { inherit moduleRegistry; }) {
  hardware = import ./hardware.nix;

  # Kvantum is a Qt Widgets style, not a Qt Quick Controls style. Clear
  # both shell and systemd-user environments so Plasma QML loads normally.
  home-manager.users.${config.dotfiles.users.primary.name} = {
    home.sessionVariables.QT_STYLE_OVERRIDE = lib.mkForce "";
    systemd.user.sessionVariables.QT_STYLE_OVERRIDE = lib.mkForce "";
  };

  # The Pi boots through firmware/U-Boot instead of an EFI boot manager.
  boot.loader = {
    grub.enable = false;
    generic-extlinux-compatible = {
      enable = true;
      configurationLimit = 5;
    };
  };

  dotfiles = {
    scopes = {
      system.boot.loader.enable = false;
      virtualisation.enable = false;

      desktopApps = {
        waypipe.enable = false;
        keymapp.enable = false;
        vial.enable = false;
        openclaw.enable = false;
        openWebui.enable = false;
        thunderbird.enable = false;
        obsidian.enable = false;
        githubDesktop.enable = false;
        pycharm.enable = false;
        libreoffice.enable = false;
        ollama.enable = false;
        discord.enable = false;
        onlyoffice.enable = false;
        beeperMatrixClient.enable = false;
        chatgpt.enable = false;
        bambuStudio.enable = false;
        prusaSlicer.enable = false;
        orcaSlicerNightly.enable = false;
        gimp.enable = false;
        inkscape.enable = false;
        krita.enable = false;
      };
    };
  };

  networking = editScope moduleRegistry.networking {
    ssh = _: {
      users.users.${config.dotfiles.users.primary.name}.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMZdbT05P/naiv07J32DxHDOR5A1z8F9jijeBrDkXWV joshankana@gmail.com"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBU9mnHy1HP+StbXl3HmTSpOVJ1VETv9DYWUj1YmzDKc chatgpt-shell-nixos-pi"
      ];

      systemd.tmpfiles.rules = [
        "f+ /etc/elevation-authorized-key 0444 root root - ${
          lib.concatStringsSep "\\n" [
            "ssh-ed25519\\x20AAAAC3NzaC1lZDI1NTE5AAAAIEBfBg52XAZkpWk2cKNqvITRhsrnmEdz8yon5bpZZP/w\\x20joshan@nixos-pi-sudo"
            "ssh-ed25519\\x20AAAAC3NzaC1lZDI1NTE5AAAAIMgQFxMmgs5HwY+l9twQBUEt672VOFrmgAnOKuoMuzz/\\x20nixos-pi-sudo"
          ]
        }\\n"
      ];
    };
  };
}
