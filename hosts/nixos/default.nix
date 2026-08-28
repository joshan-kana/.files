{
  inputs,
  moduleRegistry,
  pkgs,
  ...
}:

{
  inherit (moduleRegistry)
    system
    nix
    theme
    networking
    appimage
    audio
    virtualisation
    desktop
    desktopApps
    ;

  imports = [
    inputs.spicetify-nix.nixosModules.spicetify
  ];

  hardware = import ./hardware.nix;

  dotfiles = {
    profile.name = "nixos";
    rebuild.flags = "--impure";
  };

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

  cli =
    {
      config,
      inputs,
      lib,
      pkgs,
      ...
    }:
    (moduleRegistry.cli {
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

}
