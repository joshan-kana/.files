{ config, pkgs, spicetify-nix, ollamaUrl, dotfilesPath, profileName, nixosRebuildFlags, ... }:

{
  # User information
  home.username = "joshan";
  home.homeDirectory = "/home/joshan";

  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.05"; # Please read the comment before changing.

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Allow non-free pkgs
  nixpkgs.config.allowUnfree = true;

  # List of programs
  home.packages = with pkgs; [
  ];

  # My first set of dotfiles
  # git
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Joshan Kana";
        email = "joshankana@gmail.com";
      };
      extraConfig = {
        init.defaultBranch = "main";
      };
    };
  };

  # Widgets: Eww
  programs.eww = {
    enable = true;
    package = pkgs.eww;
    configDir = ./desktop/eww;
  };

  # Application launcher: Wofi
  programs.wofi = {
    enable = true;
    settings = {
      allow_images = true;
      matching = "fuzzy";
    };
  };

  # General Launcher: Rofi
  # Not being used as much due to excessively long startup times
  # Was using rofi-wayland, but that was the version that caused slow startup times (only when installed via home-manager)
  # Standard X11 rofi seems uneffected
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    terminal = "kitty";
    plugins = with pkgs; [
      rofi-calc
    ];
  };

  # General Launcher: Tofi
  # Installed in nixos configuration
  home.file.".config/tofi/config" = {
    text = "
      # Initial config of tofi!
      font = ${config.stylix.fonts.monospace.name}
      font-size = 18
      #
      # Colours
      #
      # Default text-color
      background-color = #${config.lib.stylix.colors.base00}
      text-color = #${config.lib.stylix.colors.base07}
      selection-color = #${config.lib.stylix.colors.base0A}
      #
      # Window config
      width = 45%
      height = 35%
      border-width = 5
      border-color = #${config.lib.stylix.colors.base03}
      corner-radius = 20
    ";
  };

  # Top Bar: Waybar
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        spacing = 10;
        modules-left = [ "hyprland/workspaces" "mpris" ];
        modules-center = [ "clock" ];
        modules-right = [ "backlight" "wireplumber" "battery" "tray" ];

        "hyprland/workspaces" = {
          on-scroll-up = "hyprctl dispatch workspace e+1";
          on-scroll-down = "hyprctl dispatch workspace e-1";
        };

        "mpris" = {
          interval = 1;
          format = "{player}: {status_icon} {position}/{length}";
          status-icons = {
            playing = "▶";
            paused = "⏸";
          };
        };

        "clock" = {
          format = "⎈ {:%a, %b %d |  %R}";
        };

        "backlight" = {
          format = "{percent}% {icon}";
          format-icons = [ "" "" ];
          scroll-step = 0.35;
        };

        "battery" = {
          interval = 120;
          format = "{capacity}% {icon}";
          format-icons = [ "" "" "" "" "" ];
        };

        "wireplumber" = {
          format = "{volume}% {icon}";
          format-icons = [ "" "" "" ];
          scroll-step = 0.35;
        };

        "tray" = {
          spacing = 10;
        };
      };
    };
  };

  # Screen-locker: Swaylock
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
  };

  # Clipboard Manager: Cliphist
  services.cliphist.enable = true;

  # Notifications: Dunst
  services.dunst = {
    enable = true;
    settings = {
      global = {
        mouse_right_click = "do_action";
        dmenu = "/home/joshan/.nix-profile/bin/rofi -dmenu";
      };
    };
  };

  # OSD: Avizo
  services.avizo = {
    enable = true;
    settings = {
      default = {
        time = 1.0;
        fade-in = 0.1;
        fade-out = 0.2;
        padding = 10;
      };
    };
  };

  # Sound
  # Audio Effects: EasyEffects
  services.easyeffects.enable = true;

  # set the styling type for qt applications to use "qtct" and not "kde"
  stylix.targets.qt.platform = "qtct";

  # Terminal stuff
  # Terminal Emulators
  # Kitty
  programs.kitty = {
    enable = true;
    extraConfig = ''
      confirm_os_window_close 0
      
      enable_audio_bell no

      input_delay 0
      touch_scroll_multiplier 3.0
    '';
  };

  # Alacritty
  programs.alacritty.enable = true;

  # Shell
  # Zsh
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    # Extra plugins for zsh
    plugins = [
      {
        # Fzf Tab Completion
        name = "zsh-fzf-tab";
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
        src = pkgs.zsh-fzf-tab;
      }
    ];
    shellAliases = {
      # Go back to the parent directory
      bk = "cd ..";

      # Edit system and home configs
      edit = "zellij attach config";
      # Edit home-manager
      homedit = "code /home/joshan/.config/home-manager";
      # Update home-manager
      homeup = "home-manager switch --flake /home/joshan/.config/home-manager";
      # Edit system
      sysedit = "code $DOTFILES/edit_config.code-workspace";
      # Update flake
      sysfu = "${dotfilesPath}/scripts/nix-flake-update ${dotfilesPath} ${profileName}";
      # Update system
      sysup = "sudo nixos-rebuild --flake $DOTFILES#$FLK_PROFILE $NIXOS_REBUILD_FLAGS switch";
      # Test system
      systest = "sudo nixos-rebuild --flake $DOTFILES#$FLK_PROFILE $NIXOS_REBUILD_FLAGS test";
      # Create VM from flake
      sysvm = "sudo nixos-rebuild --flake $DOTFILES#$FLK_PROFILE $NIXOS_REBUILD_FLAGS build-vm";

      # Launch Programs
      # Hyprland
      h = "Hyprland";

      # Hyprland on Intel
      HI = "~/.files/scripts/hyprland_intel";

      # Hyprland on Nvidia
      HN = "~/.files/scripts/hyprland_nvidia";

      # KDE Plasma
      k = "startplasma-wayland";

      # Git aliases
      # git status
      gs = "git status";

      # git log
      gl = "git log";

      # git diff
      gd = "git diff";

      # git add
      ga = "git add";

      # git commit
      gc = "git commit -m";

      # git commit all
      gca = "git commit -a -m";

      # git pull
      gpl = "git pull";

      # git push
      gph = "git push";

      # Ollama (in docker)
      ollama = "docker exec -it ollama ollama";

      # Neovim alias
      v = "nvim";

      # ls alias
      l = "eza -a";
      ll = "eza -lah";
      ls = "eza";

      # neofetch alias
      neofetch = "fastfetch";

      # copy current path/directory to clipboard
      cpd = ''printf "%s" \"$(pwd | tr -d "\n")\" | wl-copy && echo "📋 Copied path!"'';

      # playing audio files (my music) with my preferred options (no pitch correction when slowing down and looping enabled)
      p = "mpv --audio-pitch-correction=no --loop=yes";

      # size of directory or file with preffered flags
      sz = "du -sh";

      # allow direnv to load in directory
      da = "direnv allow";
    };
    initContent = ''
      # Keybindings
      # Moving forwards and backwards by a word
      bindkey "^[[1;5D" backward-word
      bindkey "^[[1;5C" forward-word
      
      # Deleting by a word
      bindkey "^H" backward-kill-word
      bindkey "^[[3;3~" kill-word

      # Edit command line in editor
      autoload -U edit-command-line
      zle -N edit-command-line
      bindkey '^xe' edit-command-line
      bindkey '^x^e' edit-command-line

      # fix bug in zsh where can't delete left of cursor after entering normal mode and then insert mode
      bindkey -v '^?' backward-delete-char
    '';
  };

  # Shell Prompt
  # starship
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      character.success_symbol = "[➜](bold green) ";
      character.error_symbol = "[✗](bold red) ";
      container.disabled = true;
    };
  };

  # Terminal Multiplexers
  # Tmux
  programs.tmux = {
    enable = true;
  };

  # tmuxai (not a plugin, standalone app for tmux)
  home.file.".config/tmuxai/config.yaml" = {
    text = ''
      models:
        primary:
          provider: openrouter
          model: gemma3:12b
          api_key: XXXXXXXXXXXXXXX
          base_url: ${ollamaUrl}
    '';
  };

  # Zellij
  programs.zellij = {
    enable = true;
    # enableZshIntegration = true;
  };

  # Terminal/CLI tools
  # Fzf (fuzzy finder)
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
  # Ripgrep (faster grep)
  programs.ripgrep.enable = true;
  # File explorer
  programs.lf.enable = true;
  # Bat (cat clone)
  programs.bat.enable = true;
  # Eza (a better ls)
  programs.eza.enable = true;

  # System monitors (TUI)

  # Htop
  programs.htop.enable = true;

  # Btop
  programs.btop = {
    enable = true;
    settings = {
      update_ms = 100;
    };
  };

  # Text editors
  # Neovim
  programs.neovim = {
    enable = true;
    extraConfig = ''
      autocmd BufRead * autocmd FileType <buffer> ++once
      \ if &ft !~# 'commit\|rebase' && line("'\"") > 1 && line("'\"") <= line("$") | exe 'normal! g`"' | endif
    '';
  };

  # VSCode
  programs.vscode.enable = true;

  # Disabling stylix for vscode
  stylix.targets.vscode.enable = false;


  # Browsers
  # Firefox
  programs.firefox.enable = true;
  # enable theming from stylix
  stylix.targets.firefox.profileNames = [ "themed" ];
  stylix.targets.firefox.colorTheme.enable = true;
  programs.firefox.profiles.themed.extensions.force = true;
  # Floorp
  programs.floorp.enable = true;
  stylix.targets.floorp.profileNames = [ "themed" ];
  stylix.targets.floorp.colorTheme.enable = true;
  programs.floorp.profiles.themed.extensions.force = true;
  # Brave (add to home.packages)

  # Media Players
  programs.mpv = {
    enable = true;
    scripts = with pkgs; [
      mpvScripts.mpris
    ];
  };

  # Music Streaming Setup
  # NCMPCPP
  programs.ncmpcpp = {
    enable = true;
    package = pkgs.ncmpcpp.override { visualizerSupport = true; };
  };

  # Files: Dropbox
  # services.dropbox.enable = true;

  # Eye Candy
  programs.cava.enable = true;
  programs.cava.settings = {
    general.lower_cutoff_freq = 20;
    general.upper_cutoff_freq = 20000;
    smoothing.noise_reduction = 30;
    smoothing.monstercat = 1;
    general.bar_width = 1;
    general.bar_spacing = 0;
    output.channels = "mono";

    # Colours
    color.gradient = 1;
    color.gradient_count = 8;
    # color.gradient_color_1 = "'#${config.lib.stylix.colors.base00}'";
    color.gradient_color_1 = "'#${config.lib.stylix.colors.base01}'";
    color.gradient_color_2 = "'#${config.lib.stylix.colors.base02}'";
    color.gradient_color_3 = "'#${config.lib.stylix.colors.base03}'";
    color.gradient_color_4 = "'#${config.lib.stylix.colors.base04}'";
    color.gradient_color_5 = "'#${config.lib.stylix.colors.base05}'";
    color.gradient_color_6 = "'#${config.lib.stylix.colors.base06}'";
    color.gradient_color_7 = "'#${config.lib.stylix.colors.base07}'";
    color.gradient_color_8 = "'#${config.lib.stylix.colors.base08}'";
  };

  # GTK Icon Theme
  gtk.iconTheme = {
    package = pkgs.gruvbox-dark-icons-gtk;
    name = "oomox-gruvbox-dark";
  };
}
