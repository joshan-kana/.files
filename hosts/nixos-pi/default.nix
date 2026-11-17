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

  dotfiles = {
    defaults.browser = "firefox";
    scopes = {
      system.boot.loader.enable = false;
      virtualisation.enable = false;

      desktopApps = {
        waypipe.enable = false;
        zed.enable = false;
        keymapp.enable = false;
        vial.enable = false;
        openclaw.enable = false;
        openWebui.enable = false;
        thunderbird.enable = false;
        obsidian.enable = false;
        githubDesktop.enable = false;
        pycharm.enable = false;
        libreoffice.enable = false;
        sunshine.enable = false;
        ollama.enable = false;
        discord.enable = false;
        dropbox.enable = false;
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
      ];
    };
  };
}
