{ inputs, modulesPath, ... }:

let
  modules = import ../../modules;
in
{
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
    ./options.nix
    (import ../../modules/virtualisation/containers/image-locking.nix {
      lockFile = ./container-images.lock;
    })
    "${modulesPath}/image/repart.nix"
  ];

  inherit (modules)
    system
    theme
    cli
    serverApps
    ;
  nix =
    {
      config,
      inputs,
      ...
    }:
    (modules.nix { inherit config; })
    // {
      home-manager.sharedModules = [
        "${inputs.home-manager}/modules/programs/attic-client.nix"
      ];
      users.users.${config.dotfiles.users.primary.name}.linger = true;
    };
  networking = import ./networking.nix;
  virtualisation =
    {
      config,
      pkgs,
      ...
    }:
    let
      shared = modules.virtualisation { inherit config pkgs; };
    in
    shared
    // {
      containers =
        { config, ... }:
        (shared.containers { inherit config; })
        // {
          virtualisation.oci-containers.backend = "docker";
        };

      vm = _: (shared.vm { }) // { safety = import ./vm-safety.nix; };
    };
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
    scopes.virtualisation = {
      libvirt.enable = false;
      quickemu.enable = false;
      distrobox.enable = false;
      bottles.enable = false;
      vm.aliases.enable = false;
    };
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
