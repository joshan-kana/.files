{
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    ../../modules/options
    inputs.spicetify-nix.nixosModules.spicetify
  ];

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

  system = import ../../modules/system;
  nix = import ../../modules/nix.nix;
  theme = import ../../modules/theme;
  cli =
    {
      config,
      inputs,
      lib,
      pkgs,
      ...
    }:
    (import ../../modules/cli.nix {
      inherit
        config
        inputs
        lib
        pkgs
        ;
    })
    // {
      nvtop = _: {
        nixpkgs.overlays = (import ../../overlays/nvtop-overlay.nix { }).nixpkgs.overlays;
        environment.systemPackages = [ pkgs.nvtopPackages.full ];
      };

      intelGpuTools = _: {
        environment.systemPackages = [ pkgs.intel-gpu-tools ];
      };
    };
  networking = import ../../modules/networking.nix;
  appimage = import ../../modules/appimage.nix;
  ssh = import ../../modules/ssh.nix;
  audio = import ../../modules/audio.nix;
  virtualisation = import ../../modules/virtualisation.nix;
  desktop = import ../../modules/desktop;
  vm = import ../../modules/vm.nix;

  # Shared desktop apps are implemented in modules/apps.nix. These additional
  # children intentionally remain on this host because their packages/services
  # are part of the x86_64-linux-only desktop inventory.
  apps =
    {
      inputs,
      pkgs,
      ...
    }:
    (import ../../modules/apps.nix { inherit inputs pkgs; })
    // {
      brave = _: {
        environment.systemPackages = [ pkgs.brave ];
      };

      spotify = _: {
        programs.spicetify.enable = true;
      };

      bitwarden = _: {
        environment.systemPackages = [ pkgs.bitwarden-desktop ];
      };

      discord = _: {
        environment.systemPackages = [ pkgs.discord ];
      };

      dropbox = _: {
        environment.systemPackages = [ pkgs.dropbox ];
      };

      warp = _: {
        environment.systemPackages = [ pkgs.warp-terminal ];
      };

      onlyoffice = _: {
        environment.systemPackages = [ pkgs.onlyoffice-desktopeditors ];
      };

      twingate = _: {
        services.twingate.enable = true;
      };
    };

  hardware = import ./hardware.nix;

  dotfiles = {
    profile.name = "nixos";
    rebuild.flags = "--impure";
  };
}
