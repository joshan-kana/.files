{
  editScope,
  extendScope,
  moduleRegistry,
  ...
}:

{
  inherit (moduleRegistry)
    nix
    theme
    networking
    virtualisation
    desktopApps
    backups
    ;

  dotfiles.users.primary.homeRoot = "/Users";

  system = editScope moduleRegistry.system {
    compatibility = _: {
      system.stateVersion = 6;
      home = _: {
        home.stateVersion = "26.05";
      };
    };

    identity = { config, ... }: {
      home-manager = {
        backupFileExtension = "before-nix";
        extraSpecialArgs.configurationName = config.dotfiles.profile.name;
        sharedModules = [ ../../modules/options ];
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
        programs.zsh.initContent = lib.mkAfter ''
          zd() {
            zip -qry /tmp/upload.zip . && osascript -e 'set the clipboard to POSIX file "/tmp/upload.zip"'
          }
        '';
      };
    };
  };

  desktop = extendScope moduleRegistry.desktop {
    macPreferences = _: {
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
  };
}
