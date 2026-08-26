{ inputs, modulesPath, ... }:

{
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
    ../../modules/options/common.nix
    ./options.nix
    "${modulesPath}/image/repart.nix"
  ];

  system = import ../../modules/system.nix;
  nix = import ../../modules/nix.nix;
  cli = import ../../modules/cli.nix;
  networking = import ./networking.nix;
  containers = import ./containers.nix;
  containerImageLocking = import ./container-image-locking.nix;
  apps = import ./apps;
  storage = import ./storage.nix;
  vm = import ../../modules/vm.nix;
  vmSafety = import ./vm-safety.nix;
  image = import ./image.nix;
  hardware = import ./hardware.nix;
  maintenance = import ./maintenance.nix;
  access = import ./access.nix;
  compatibility = import ./compatibility.nix;

  dotfiles = {
    profile.name = "nixos-server";
    scopes.vm.aliases.enable = false;
    scopes.cli = {
      clipboard.enable = false;
      mpv.enable = false;
      tmuxai.enable = false;
      ollama.enable = false;
    };
  };
}
