{
  config,
  inputs,
  ...
}:

{
  imports = [
    ../../modules/options/common.nix
  ];

  system = import ../../modules/system;
  nix = import ../../modules/nix.nix;
  theme = import ../../modules/theme.nix;
  cli = import ../../modules/cli.nix;
  networking = import ../../modules/networking.nix;
  vm = import ../../modules/vm.nix;
  boot = import ../../modules/boot.nix;
  ssh = import ../../modules/ssh.nix;
  mullvad = import ../../modules/mullvad.nix;
  desktop = import ../../modules/desktop;
  apps = import ./apps.nix;
  gpuTools = import ./gpu-tools.nix;
  twingate = import ./twingate.nix;
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
