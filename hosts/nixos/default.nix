{
  extendScope,
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

  dotfiles = {
    rebuild.flags = "--impure";
    scopes.system.boot.splash.enable = true;
  };

  hardware = import ./hardware.nix;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  cli = extendScope moduleRegistry.cli {
    nvtop = _: {
      home = _: { home.packages = [ pkgs.nvtopPackages.full ]; };
    };

    intelGpuTools = _: {
      home = _: { home.packages = [ pkgs.intel-gpu-tools ]; };
    };
  };

}
