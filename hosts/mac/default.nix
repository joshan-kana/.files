{
  config,
  editScope,
  extendScope,
  moduleRegistry,
  pkgs,
  ...
}:

{
  inherit (moduleRegistry)
    nix
    networking
    backups
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

  theme = extendScope moduleRegistry.theme {
    macTargets = _: {
      home = _: {
        stylix = {
          autoEnable = false;
          targets = {
            btop.enable = true;
            fzf.enable = true;
            lazygit.enable = true;
            neovim.enable = true;
            starship.enable = true;
            tmux.enable = true;
            yazi.enable = true;
            zellij.enable = true;
          };
        };
      };
    };
  };

  cli = extendScope moduleRegistry.cli (import ./cli.nix);

  desktopApps = extendScope moduleRegistry.desktopApps (import ./desktop-apps.nix);

  virtualisation = extendScope moduleRegistry.virtualisation {
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

  desktop = extendScope moduleRegistry.desktop {
    hammerspoon = import ../../modules/desktop/hammerspoon;
    yabai = import ../../modules/desktop/yabai;
    raycast = _: {
      environment.systemPackages = [ pkgs.raycast ];
    };
    karabinerElements = _: {
      services.karabiner-elements.enable = true;
    };
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
