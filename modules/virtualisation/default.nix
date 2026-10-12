{
  config,
  lib,
  pkgs,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isLinux;
  linuxOnly =
    scope: lib.setFunctionArgs (args: lib.optionalAttrs isLinux (scope args)) (lib.functionArgs scope);
in
{
  /**
    Shared OCI/Docker container runtime and image-locking support.
  */
  containers = linuxOnly (import ./containers);

  /**
    libvirt/QEMU virtual-machine support and virt-manager integration.
  */
  libvirt = linuxOnly (_: {
    virtualisation.libvirtd = {
      enable = true;
      qemu.swtpm.enable = true;
    };

    programs.virt-manager.enable = true;

    users.users.${config.dotfiles.users.primary.name}.extraGroups = [ "libvirtd" ];
  });

  /**
    Quickemu tooling for disposable desktop virtual machines.
  */
  quickemu = linuxOnly (_: {
    environment.systemPackages = [ pkgs.quickemu ];
  });

  /**
    Distrobox tooling for user-managed development containers.
  */
  distrobox = linuxOnly (_: {
    environment.systemPackages = [ pkgs.distrobox ];
  });

  /**
    Bottles application support.
  */
  bottles = linuxOnly (_: {
    environment.systemPackages = [ pkgs.bottles ];
  });

  /**
    Shared NixOS VM-variant sizing, aliases, and safety defaults.
  */
  vm = linuxOnly (import ./vm.nix);
}
// import ./darwin.nix
