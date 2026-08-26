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
  nix =
    {
      config,
      inputs,
      ...
    }:
    (import ../../modules/nix { inherit config; })
    // {
      home-manager.sharedModules = [
        "${inputs.home-manager}/modules/programs/attic-client.nix"
      ];
      users.users.${config.dotfiles.users.primary.name}.linger = true;
    };
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

  compatibility = _: {
    system.stateVersion = "25.05";
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
