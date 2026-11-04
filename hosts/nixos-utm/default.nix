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
    (moduleRegistry.profiles { inherit lib; }).desktop.default
    (moduleRegistry.profiles { inherit lib; }).desktop.arm
  ];

  hardware = import ./hardware.nix;

  # The guest intentionally runs from an unmerged review branch. Do not let
  # automatic deployments replace that branch with the published main branch.
  dotfiles.scopes = {
    system.autoDeploy.enable = false;
    networking.tailscaleClient.enable = false;
    virtualisation.children.enable = false;
  };

  users.users.${config.dotfiles.users.primary.name}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMZdbT05P/naiv07J32DxHDOR5A1z8F9jijeBrDkXWV joshankana@gmail.com"
  ];

  boot = {
    initrd.kernelModules = [ "virtio_gpu" ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
  };

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
  services.fstrim.enable = true;

  environment.systemPackages = with pkgs; [
    mesa-demos
    vulkan-tools
    wayland-utils
  ];
}
