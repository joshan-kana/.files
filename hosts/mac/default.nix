{
  config,
  homeModule,
  lib,
  moduleRegistry,
  pkgs,
  ...
}:

let
  primary = config.dotfiles.users.primary.name;
  themeRegistry = import ../../modules/theme/registry.nix { inherit lib pkgs; };
  theme = themeRegistry.resolve themeRegistry.default;
  sharedCli =
    { osConfig, pkgs, ... }:
    let
      scope = moduleRegistry.cli {
        config = osConfig;
        inherit pkgs;
        configurationOutputName = "mac";
        configurationFlakeSubdirectory = null;
      };
    in
    lib.getAttrs [
      "bat"
      "btop"
      "clipboard"
      "direnv"
      "dust"
      "eza"
      "fastfetch"
      "fzf"
      "gh"
      "git"
      "glow"
      "htop"
      "jujutsu"
      "neovim"
      "nixShell"
      "ripgrep"
      "starship"
      "tmux"
      "tree"
      "yazi"
      "zellij"
      "zsh"
    ] scope
    // {
      inherit (scope) home;
    };
in
{
  # Determinate owns the existing Nix daemon and its settings.
  nix.enable = false;
  system.stateVersion = 6;
  system.primaryUser = primary;

  users.users.${primary}.home = "/Users/${primary}";
  dotfiles.users.primary.homeRoot = "/Users";

  # Install only foundational, non-creative Mac applications here.
  homebrew = {
    enable = true;
    onActivation.cleanup = "none";
    taps = [ "asmvik/formulae" ];
    brews = [ "asmvik/formulae/yabai" ];
    casks = [
      "hammerspoon"
      "karabiner-elements"
      "raycast"
    ];
  };

  stylix = {
    enable = true;
    inherit (theme) polarity;
    base16Scheme = {
      system = "base16";
      name = theme.label;
      variant = theme.polarity;
      palette = theme.colors;
    };
    inherit (theme) fonts;
  };

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

  home-manager = {
    # Preserve the hand-maintained originals when Home Manager first takes ownership.
    backupFileExtension = "before-nix";
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${primary} =
      { lib, ... }:
      {
        imports = [
          (homeModule "cli" sharedCli)
          (homeModule "desktop" (_: {
            hammerspoon = import ../../modules/desktop/hammerspoon;
            yabai = import ../../modules/desktop/yabai;
          }))
        ];

        home = {
          username = primary;
          homeDirectory = "/Users/${primary}";
          stateVersion = "26.05";
          sessionPath = [ "$HOME/.local/bin" ];
          shellAliases = {
            p = "mpv --audio-pitch-correction=no --loop=yes";
            upcheck = "brew update && brew upgrade -gny";
            update = "sudo -v && brew upgrade -g --no-ask";
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
            bat.enable = true;
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
