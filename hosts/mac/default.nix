{
  editScope,
  extendScope,
  moduleRegistry,
  ...
}:

{
  inherit (moduleRegistry)
    theme
    networking
    backups
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

  inherit (moduleRegistry)
    desktop
    desktopApps
    ;

  virtualisation = editScope moduleRegistry.virtualisation {
    orbStack = _: {
      home = _: {
        home.shellAliases.o = "orb";
        programs.zsh.profileExtra = ''
          if [[ -f "$HOME/.orbstack/shell/init.zsh" ]]; then
            source "$HOME/.orbstack/shell/init.zsh"
          fi
        '';
      };
    };
  };
}
