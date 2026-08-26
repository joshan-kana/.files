{
  config,
  inputs,
  ...
}:

{
  imports = [
    ../../modules/options/common.nix
  ];

  system = import ../../modules/system.nix;
  nix = import ../../modules/nix.nix;
  cli = import ../../modules/cli.nix;
  networking = import ../../modules/networking.nix;
  vm = import ../../modules/vm.nix;
  desktop = import ../../modules/desktop.nix;
  nvtop = import ../../overlays/nvtop-overlay.nix;
  x86 = import ./x86.nix;
  hardware = import ./hardware.nix;

  home-manager.users.${config.dotfiles.users.primary.name}.imports = [
    inputs.plasma-manager.homeModules.plasma-manager
    inputs.spicetify-nix.homeManagerModules.default
  ];

  dotfiles = {
    profile.name = "nixos";
    rebuild.flags = "--impure";
  };
}
