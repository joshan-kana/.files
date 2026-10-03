{
  config,
  editScope,
  lib,
  moduleRegistry,
  pkgs,
  ...
}:

{
  inherit (moduleRegistry)
    system
    backups
    nix
    cli
    networking
    appimage
    audio
    virtualisation
    desktopApps
    desktop
    ;

  imports = [
    (moduleRegistry.profiles { inherit lib; }).desktop.arm
  ];

  theme = editScope moduleRegistry.theme {
    runtimeSwitching = true;
  };

  dotfiles = {
    defaults.terminal = "alacritty";
  };

  hardware = import ./hardware.nix;

  users.users.${config.dotfiles.users.primary.name}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMZdbT05P/naiv07J32DxHDOR5A1z8F9jijeBrDkXWV joshankana@gmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJsiQZEG5WB92zEubOX4InNHN4ev8byz2KBwzGLzMWPA chatgpt-shell-nixos-arm-parallels"
  ];

  security.pam.sshAgentAuth = {
    enable = true;
    authorizedKeysFiles = [ "/etc/sudo-authorized-key" ];
  };

  security.sudo = {
    extraConfig = ''
      Defaults:${config.dotfiles.users.primary.name} noninteractive_auth
    '';
    wheelNeedsPassword = true;
  };

  systemd.tmpfiles.rules = [
    "f+ /etc/sudo-authorized-key 0444 root root - ssh-ed25519\\x20AAAAC3NzaC1lZDI1NTE5AAAAIGRtvQBAj3/3cJYqS4KosghtI5fsh9poh3q+LIfFL8KR\\x20joshan@nixos-arm-parallels-sudo\\n"
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
    plymouth.enable = false;
  };

}
