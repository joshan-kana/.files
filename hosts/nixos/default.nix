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
    scopes.theme.bootMenu.enable = true;
  };

  hardware = import ./hardware.nix;

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

  cli = extendScope moduleRegistry.cli {
    nvtop = _: {
      home = _: { home.packages = [ pkgs.nvtopPackages.full ]; };
    };

    intelGpuTools = _: {
      home = _: { home.packages = [ pkgs.intel-gpu-tools ]; };
    };
  };

}
