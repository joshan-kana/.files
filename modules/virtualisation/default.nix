{
  config,
  lib,
  pkgs,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux;
  linuxScope =
    scope: lib.setFunctionArgs (args: lib.optionalAttrs isLinux (scope args)) (lib.functionArgs scope);
in
{
  /**
    Shared OCI/Docker container runtime and image-locking support.
  */
  containers = linuxScope (import ./containers);

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
  vm = linuxScope (import ./vm.nix);

  /**
    OrbStack macOS virtualisation and shell integration.
  */
  orbStack =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: {
        home.packages = [ pkgs.orbstack ];
        home.shellAliases.o = "orb";
        programs.zsh.profileExtra = ''
          if [[ -f "$HOME/.orbstack/shell/init.zsh" ]]; then
            source "$HOME/.orbstack/shell/init.zsh"
          fi
        '';
      };
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
