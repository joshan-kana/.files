{
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    ../../modules/options
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

  system = import ../../modules/system;
  nix = import ../../modules/nix;
  theme = import ../../modules/theme;
  cli =
    {
      config,
      inputs,
      lib,
      pkgs,
      ...
    }:
    (import ../../modules/cli {
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
  networking = import ../../modules/networking;
  appimage = import ../../modules/appimage;
  ssh = import ../../modules/ssh;
  audio = import ../../modules/audio;
  virtualisation = import ../../modules/virtualisation;
  desktop = import ../../modules/desktop;

  desktopApps = import ../../modules/desktop-apps;

  hardware = import ./hardware.nix;

  dotfiles = {
    profile.name = "nixos";
    rebuild.flags = "--impure";
  };
}
