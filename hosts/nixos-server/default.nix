{ inputs, modulesPath, ... }:

{
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
    ../../modules/options
    ./options.nix
    (import ../../modules/containers/image-locking.nix { lockFile = ./container-images.lock; })
    "${modulesPath}/image/repart.nix"
  ];

  system = import ../../modules/system;
  nix = import ../../modules/nix.nix;
  theme = import ../../modules/theme.nix;
  cli = import ../../modules/cli.nix;
  networking = import ./networking.nix;
  containers = import ../../modules/containers;
  apps = import ./apps;
  storage = import ./storage.nix;
  vm = import ../../modules/vm.nix;
  vmSafety = import ./vm-safety.nix;
  image = import ./image.nix;
  hardware = import ./hardware.nix;
  maintenance = import ./maintenance.nix;
  access = import ./access.nix;

  compatibility = _: {
    system.stateVersion = "25.05";
  };

  dotfiles = {
    profile.name = "nixos-server";
    scopes.vm.aliases.enable = false;
    scopes.cli = {
      clipboard.enable = false;
      mpv.enable = false;
      tmuxai.enable = false;
      ollama.enable = false;
      cava.enable = false;
      ncmpcpp.enable = false;
      youtubeTui.enable = false;
      stow.enable = false;
      killall.enable = false;
      xdgUtils.enable = false;
      trashCli.enable = false;
      gnumake.enable = false;
      devbox.enable = false;
      has.enable = false;
      nvd.enable = false;
      nixTree.enable = false;
      python.enable = false;
    };
  };
}
