{
  config,
  lib,
  moduleRegistry,
  ...
}:

lib.recursiveUpdate (import ../../profiles/workstation.nix { inherit moduleRegistry; }) {
  hardware = import ./hardware.nix;

  boot.loader = {
    grub.enable = false;
    generic-extlinux-compatible.enable = true;
  };

  dotfiles.defaults.browser = "firefox";

  dotfiles.scopes = {
    # Raspberry Pi firmware and U-Boot use extlinux, not an EFI boot manager.
    system.boot.loader.enable = false;

    # This is a media workstation, not a VM or container host.
    virtualisation.enable = false;

    # Keep the Hyprland desktop but omit the second full desktop environment.
    desktop.plasma.enable = false;

    cli = {
      codex.enable = false;
      crush.enable = false;
      devbox.enable = false;
      esptool.enable = false;
      ollama.enable = false;
      tio.enable = false;
    };

    # Avoid heavyweight development, background services, and x86-only apps.
    desktopApps = {
      alacritty.enable = false;
      ghostty.enable = false;
      coolRetroTerm.enable = false;
      chromium.enable = false;
      googleChrome.enable = false;
      waypipe.enable = false;
      zed.enable = false;
      keymapp.enable = false;
      vial.enable = false;
      openclaw.enable = false;
      openWebui.enable = false;
      brave.enable = false;
      zen.enable = false;
      warp.enable = false;
      mullvad.enable = false;
      thunderbird.enable = false;
      obsidian.enable = false;
      githubDesktop.enable = false;
      vscode.enable = false;
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

  # The offline provisioning step writes the hash to the Btrfs root image,
  # outside Git and the Nix store.
  users.users.${config.dotfiles.users.primary.name} = {
    initialPassword = lib.mkForce null;
    hashedPasswordFile = "/var/lib/nixos-pi/password-hash";
    uid = 1000;
    openssh.authorizedKeys.keyFiles = [ ./authorized-key.pub ];
  };

  services.openssh.settings.PermitRootLogin = "no";
}
