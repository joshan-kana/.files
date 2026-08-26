{ inputs, modulesPath, ... }:

{
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
    ../../modules/options
    ./options.nix
    (import ../../modules/virtualisation/containers/image-locking.nix {
      lockFile = ./container-images.lock;
    })
    "${modulesPath}/image/repart.nix"
  ];

  system = import ../../modules/system;
  nix = import ../../modules/nix;
  theme = import ../../modules/theme;
  cli = import ../../modules/cli;
  networking = import ./networking.nix;
  virtualisation = _: {
    containers =
      { config, ... }:
      (import ../../modules/virtualisation/containers { inherit config; })
      // {
        virtualisation.oci-containers.backend = "docker";
      };

    vm =
      _:
      (import ../../modules/virtualisation/vm.nix { })
      // {
        safety = import ./vm-safety.nix;
      };
  };
  apps = import ./apps;
  storage = import ./storage.nix;
  image = import ./image.nix;
  hardware = import ./hardware.nix;
  maintenance = import ./maintenance.nix;
  access = import ./access.nix;

  compatibility = { lib, ... }: {
    # Preserve pre-refactor evaluator ownership while shared modules expose
    # both native NixOS and Home Manager configurations. Remove selectively
    # in post-merge behavior changes when enabling the new side is desired.
    system.stateVersion = "25.05";

    programs = {
      lazygit.enable = lib.mkForce false;
      starship.enable = lib.mkForce false;
      neovim.enable = lib.mkForce false;
    };

    home = { lib, ... }: {
      programs = {
        nh.enable = lib.mkForce false;
        direnv.enable = lib.mkForce false;
      };
    };
  };

  dotfiles = {
    profile.name = "nixos-server";
    scopes.virtualisation.vm.aliases.enable = false;
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
      python3.enable = false;
    };
  };
}
