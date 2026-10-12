{
  config,
  editScope,
  extendScope,
  moduleRegistry,
  ...
}:

{
  inherit (moduleRegistry)
    nix
    networking
    backups
    theme
    desktopApps
    virtualisation
    ;

  system =
    extendScope
      (editScope moduleRegistry.system {
        compatibility = _: {
          system.stateVersion = 6;
        };
        identity = _: {
          system.primaryUser = config.dotfiles.users.primary.name;
          users.users.${config.dotfiles.users.primary.name}.home =
            "/Users/${config.dotfiles.users.primary.name}";
        };
      })
      {
        macUser = _: {
          dotfiles.users.primary.homeRoot = "/Users";
          home-manager = {
            backupFileExtension = "before-nix";
            extraSpecialArgs.configurationName = "mac";
            sharedModules = [ ../../modules/options ];
          };
          home = { lib, ... }: {
            home.stateVersion = lib.mkForce "26.05";
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
