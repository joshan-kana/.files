{ config, inputs, ... }:

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
  hardware = import ./hardware.nix;

  home-manager.users.${config.dotfiles.users.primary.name}.imports = [
    inputs.plasma-manager.homeModules.plasma-manager
  ];

  dotfiles = {
    profile.name = "nixos-arm-parallels";
  };
}
