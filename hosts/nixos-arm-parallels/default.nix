{
  lib,
  moduleRegistry,
  pkgs,
  ...
}:

{
  imports = [
    (moduleRegistry.profiles { inherit lib; }).desktop.arm
  ];

  dotfiles.profile.name = "nixos-arm-parallels";

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
    plymouth.enable = false;
  };

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
  hardware = import ./hardware.nix;

}
