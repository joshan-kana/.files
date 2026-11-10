{
  config,
  lib,
  pkgs,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux;
in
{
  /**
    Shared OCI/Docker container runtime and image-locking support.
  */
  containers = if isLinux then import ./containers else _: { };

  /**
    libvirt/QEMU virtual-machine support and virt-manager integration.
  */
  libvirt =
    _:
    lib.optionalAttrs isLinux {
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
  quickemu =
    _:
    lib.optionalAttrs isLinux {
      home = _: { home.packages = [ pkgs.quickemu ]; };
    };

  /**
    Distrobox tooling for user-managed development containers.
  */
  distrobox =
    _:
    lib.optionalAttrs isLinux {
      home = _: { home.packages = [ pkgs.distrobox ]; };
    };

  /**
    Bottles application support.
  */
  bottles =
    _:
    lib.optionalAttrs isLinux {
      home = _: { home.packages = [ pkgs.bottles ]; };
    };

  /**
    Shared NixOS VM-variant sizing, aliases, and safety defaults.
  */
  vm = if isLinux then import ./vm.nix else _: { };

  /**
    OrbStack macOS virtualisation app; host-specific shell integration stays local.
  */
  orbStack =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: { home.packages = [ pkgs.orbstack ]; };
    };

  /**
    UTM beta virtual machine application on macOS.
  */
  utm =
    _:
    lib.optionalAttrs isDarwin {
      homebrew.casks = [ "utm@beta" ];
    };
}
