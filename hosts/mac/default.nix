{
  editScope,
  extendScope,
  moduleRegistry,
  ...
}:

let
  desktopAppsWithFloorpProfile = editScope moduleRegistry.desktopApps {
    floorp = _: {
      home = _: { programs.floorp.profiles.themed.path = "f5moon4n.default-release"; };
    };
  };
in
{
  inherit (moduleRegistry)
    theme
    networking
    backups
    desktop
    virtualisation
    ;

  dotfiles.users.primary.homeRoot = "/Users";

  nix = editScope moduleRegistry.nix {
    builders = { inherited, ... }: {
      # OrbStack runs on this Mac, so use its local SSH port.
      nix.buildMachines = map (
        builder:
        if builder.hostName == "mac.home:32223" then
          builder // { hostName = "127.0.0.1:32223"; }
        else
          builder
      ) inherited.nix.buildMachines;
    };
  };

  system =
    extendScope
      (editScope moduleRegistry.system {
        autoDeploy = _: {
          # OrbStack occupies port 4243 on this Mac.
          services.comin.exporter = {
            listen_address = "127.0.0.1";
            port = 4244;
          };
        };
      })
      {
        authentication = _: {
          security.pam.services.sudo_local.touchIdAuth = true;
        };

        preferences = _: {
          system.defaults = {
            dock = {
              autohide = true;
              show-recents = false;
              tilesize = 47;
              mru-spaces = false;
            };
            NSGlobalDomain = {
              KeyRepeat = 2;
              InitialKeyRepeat = 15;
            };
          };
        };

        homebrew = _: {
          homebrew = {
            enable = true;
            onActivation.cleanup = "none";
          };
        };

      };

  cli = extendScope moduleRegistry.cli {
    macShell = _: {
      home = { lib, ... }: {
        home = {
          sessionPath = [ "$HOME/.local/bin" ];
          shellAliases = {
            caf = "caffeinate -dims";
            sn = "ssh nixos-server";
            pvm = "ssh nixos-arm-parallels";
          };
        };
        programs.zsh.profileExtra = lib.mkBefore ''
          if [[ -x /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
            # Prefer declaratively managed tools while Homebrew remains in use.
            typeset -U path
            path=(
              "$HOME/.local/bin"
              "/etc/profiles/per-user/$USER/bin"
              "/run/current-system/sw/bin"
              "$HOME/.nix-profile/bin"
              "''${path[@]}"
            )
          fi
        '';
        programs.zsh.initContent = lib.mkAfter ''
          zd() {
            zip -qry /tmp/upload.zip . && osascript -e 'set the clipboard to POSIX file "/tmp/upload.zip"'
          }
        '';
      };
    };
  };

  desktopApps = extendScope desktopAppsWithFloorpProfile {
    notion = { pkgs, ... }: {
      home = _: { home.packages = [ pkgs.notion-app ]; };
    };

    steam = { pkgs, ... }: {
      home = _: { home.packages = [ pkgs.steam ]; };
    };

    qmkToolbox = { pkgs, ... }: {
      home = _: { home.packages = [ pkgs.qmk-toolbox ]; };
    };

    softubeCentral = _: {
      homebrew.casks = [ "softube-central" ];
    };

    cardinal = _: {
      homebrew.casks = [ "cardinal" ];
    };

    reaper = { pkgs, ... }: {
      home = _: { home.packages = [ pkgs.reaper ]; };
    };

    arduinoIde = { pkgs, ... }: {
      home = _: { home.packages = [ pkgs.arduino-ide ]; };
    };

    kicad = { pkgs, ... }: {
      home = _: { home.packages = [ pkgs.kicad ]; };
    };

    dolphinEmulator = { pkgs, ... }: {
      home = _: { home.packages = [ pkgs.dolphin-emu ]; };
    };

    heroic = { pkgs, ... }: {
      home = _: { home.packages = [ pkgs.heroic ]; };
    };

    ilokLicenseManager = _: {
      homebrew.casks = [ "ilok-license-manager" ];
    };

    izotopeProductPortal = _: {
      homebrew.casks = [ "izotope-product-portal" ];
    };

    nativeAccess = _: {
      homebrew.casks = [ "native-access" ];
    };

    parsec = _: {
      homebrew.casks = [ "parsec" ];
    };
  };

}
