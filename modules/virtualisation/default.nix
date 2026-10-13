{
  config,
  lib,
  pkgs,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isLinux;
in
lib.optionalAttrs isLinux {
  /**
    Shared OCI/Docker container runtime and image-locking support.
  */
  containers = import ./containers;

  /**
    libvirt/QEMU virtual-machine support and virt-manager integration.
  */
  libvirt = _: {
    virtualisation.libvirtd = {
      enable = true;
      qemu.swtpm.enable = true;
    };

    programs.virt-manager.enable = true;

    users.users.${config.dotfiles.users.primary.name}.extraGroups = [ "libvirtd" ];
  };

  /**
    Quickemu tooling for disposable desktop virtual machines.
  */
  quickemu = _: {
    environment.systemPackages = [ pkgs.quickemu ];
  };

  /**
    Distrobox tooling for user-managed development containers.
  */
  distrobox = _: {
    environment.systemPackages = [ pkgs.distrobox ];
  };

  /**
    Bottles application support.
  */
  bottles = _: {
    environment.systemPackages = [ pkgs.bottles ];
  };

  /**
    Shared NixOS VM-variant sizing, aliases, and safety defaults.
  */
  vm = import ./vm.nix;
}
