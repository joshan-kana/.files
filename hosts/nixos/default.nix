{
  inputs,
  moduleRegistry,
  pkgs,
  ...
}:

{
  imports = [
    inputs.spicetify-nix.nixosModules.spicetify
  ];

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

  inherit (moduleRegistry)
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
  inherit (moduleRegistry)
    networking
    appimage
    ssh
    audio
    virtualisation
    desktop
    desktopApps
    ;

  hardware = import ./hardware.nix;

}
