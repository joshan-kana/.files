{
  config,
  lib,
  moduleRegistry,
  pkgs,
  ...
}:

{
  inherit (moduleRegistry)
    system
    nix
    theme
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

  hardware = import ./hardware.nix;

  dotfiles.profile.name = "nixos-arm-parallels";

  users.users.${config.dotfiles.users.primary.name}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMZdbT05P/naiv07J32DxHDOR5A1z8F9jijeBrDkXWV joshankana@gmail.com"
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
