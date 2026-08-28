{
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

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
    plymouth.enable = false;
  };

}
