{
  inputs,
  pkgs,
  ...
}:

let
  modules = import ../../modules;
in
{
  imports = [
    inputs.spicetify-nix.nixosModules.spicetify
  ];

  # Host boot policy. AppImage binfmt support is reusable and lives in its own
  # semantic module below.
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
    plymouth.enable = false;
  };

  inherit (modules)
    system
    nix
    theme
    ;
  cli =
    {
      config,
      inputs,
      lib,
      pkgs,
      ...
    }:
    (modules.cli {
      inherit
        config
        inputs
        lib
        pkgs
        ;
    })
    // {
      nvtop = _: {
        nixpkgs.overlays = (import ../../overlays/nvtop-overlay.nix { }).nixpkgs.overlays;
        environment.systemPackages = [ pkgs.nvtopPackages.full ];
      };

      intelGpuTools = _: {
        environment.systemPackages = [ pkgs.intel-gpu-tools ];
      };
    };
  inherit (modules)
    networking
    appimage
    ssh
    audio
    virtualisation
    desktop
    desktopApps
    ;

  hardware = import ./hardware.nix;

  dotfiles = {
    profile.name = "nixos";
    rebuild.flags = "--impure";
  };
}
