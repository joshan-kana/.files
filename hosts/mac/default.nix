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
    cli
    nix
    networking
    theme
    backups
    audio
    virtualisation
    desktopApps
    appimage
    ;

  system = editScope moduleRegistry.system {
    compatibility = _: {
      system.stateVersion = 6;
    };
    identity = _: {
      system.primaryUser = config.dotfiles.users.primary.name;
      users.users.${config.dotfiles.users.primary.name}.home =
        "/Users/${config.dotfiles.users.primary.name}";
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

  dotfiles.users.primary.homeRoot = "/Users";

  # Temporary backend for the remaining casks without working Nix packages.
  homebrew = {
    enable = true;
    onActivation.cleanup = "none";
  };

  home-manager = {
    # Preserve the hand-maintained originals when Home Manager first takes ownership.
    backupFileExtension = "before-nix";
    extraSpecialArgs.configurationName = "mac";
    sharedModules = [ ../../modules/options ];
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${config.dotfiles.users.primary.name} =
      { lib, ... }:
      {
        home = {
          username = config.dotfiles.users.primary.name;
          homeDirectory = "/Users/${config.dotfiles.users.primary.name}";
          stateVersion = lib.mkForce "26.05";
          sessionPath = [ "$HOME/.local/bin" ];
          shellAliases = {
            p = "mpv --audio-pitch-correction=no --loop=yes";
            o = "orb";
            caf = "caffeinate -dims";
            sn = "ssh nixos-server";
            pvm = "ssh nixos-arm-parallels";
          };
        };
        programs.home-manager.enable = true;
        programs.zsh = {
          profileExtra = ''
            if [[ -x /opt/homebrew/bin/brew ]]; then
              eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
            if [[ -f "$HOME/.orbstack/shell/init.zsh" ]]; then
              source "$HOME/.orbstack/shell/init.zsh"
            fi
          '';
          initContent = lib.mkAfter ''
            zd() {
              zip -qry /tmp/upload.zip . && osascript -e 'set the clipboard to POSIX file "/tmp/upload.zip"'
            }
          '';
        };

        # Do not overwrite unrelated Mac application themes or GUI preferences.
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
}
