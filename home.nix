{ config, pkgs, spicetify-nix, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "joshan";
  home.homeDirectory = "/home/joshan";
  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # You can also manage environment variables but you will have to manually
  # source
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/joshan/etc/profile.d/hm-session-vars.sh
  #
  # if you don't want to manage your shell through Home Manager.
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

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
    userName = "Joshan Kana";
    userEmail = "joshankana@gmail.com";
  };

  # Widgets: Eww
  programs.eww = {
    enable = true;
    package = pkgs.eww;
    configDir = ./eww;
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
    package = pkgs.rofi-wayland;
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
	      modules-left = ["hyprland/workspaces" "mpris"];
              modules-center = ["clock"];
              modules-right = ["backlight" "wireplumber" "battery" "tray"];

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
  	      format-icons = ["" ""];
  	      scroll-step = 0.35;
  	    };

  	    "battery" = {
  	      interval = 120;
  	      format = "{capacity}% {icon}";
  	      format-icons = ["" "" "" "" ""];
  	    };

        "wireplumber" = {
          format = "{volume}% {icon}";
          format-icons = ["" "" ""];
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
    enableAutosuggestions = true;
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
      sysedit = "code /home/joshan/.files/edit_config.code-workspace";
      # Update system
      sysup = "sudo nixos-rebuild --flake /home/joshan/.files  --impure switch";
      # Test system
      systest = "sudo nixos-rebuild --flake /home/joshan/.files  --impure test";

      # Launch Programs
      # Hyprland
      # Hyprland on Intel
      HI = "~/.files/scripts/hyprland_intel";

      # Hyprland on Nvidia
      HN = "~/.files/scripts/hyprland_nvidia";

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
    };
    initExtra = ''
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
    };
  };

  # Terminal Multiplexers
  # Tmux
  programs.tmux = {
    enable = true;
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
  # Brave (add to home.packages)

  # Media Players
  programs.mpv = {
    enable = true;
    scripts = with pkgs; [
      mpvScripts.mpris
    ];
  };

  # Music Streaming Setup
  # Mopidy (MPD)
  services.mopidy = {
    enable = true;
    extensionPackages = with pkgs; [
      mopidy-mpd
      mopidy-mpris
    ];
    settings = {
      mpd = {
        enabled = true;
	hostname = "127.0.0.1";
	port = "6600";
      };
    };
  };

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

  # Stylix (colours)
  stylix.image = ./wallpaper.png;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
  stylix.fonts = {
    serif = {
      package = pkgs.nerdfonts;
      name = "JetBrainsMono Nerd Font";
    };

    sansSerif = {
      package = pkgs.nerdfonts;
      name = "JetBrainsMono Nerd Font";
    };

    monospace = {
      package = pkgs.nerdfonts;
      name = "JetBrainsMono Nerd Font";
    };

    emoji = {
      package = pkgs.noto-fonts-emoji;
      name = "Noto Color Emoji";
    };
  };
  stylix.polarity = "dark";

  stylix.cursor.package = pkgs.google-cursor;
  stylix.cursor.name = "GoogleDot-Black";
  stylix.cursor.size = 30;
  gtk.iconTheme = {
      package = (pkgs.catppuccin-papirus-folders.override { flavor = "mocha"; accent = "peach"; });
      name  = "Papirus-Dark";
  };

  # spicetify
  programs.spicetify = {
    enable = true;
    theme = spicetify-nix.packages.${pkgs.system}.default.themes.Dribbblish;
    colorScheme = "custom";

    customColorScheme = {
      text = "${config.lib.stylix.colors.base07}";
      subtext = "${config.lib.stylix.colors.base07}";
      sidebar-text = "${config.lib.stylix.colors.base07}";
      main = "${config.lib.stylix.colors.base00}";
      sidebar = "${config.lib.stylix.colors.base01}";
      player = "${config.lib.stylix.colors.base01}";
      card = "${config.lib.stylix.colors.base01}";
      shadow = "${config.lib.stylix.colors.base00}";
      selected-row = "${config.lib.stylix.colors.base0A}";
      button = "${config.lib.stylix.colors.base0C}";
      button-active = "${config.lib.stylix.colors.base0B}";
      button-disabled = "${config.lib.stylix.colors.base0D}";
      tab-active = "${config.lib.stylix.colors.base04}";
      notification = "${config.lib.stylix.colors.base03}";
      notification-error = "${config.lib.stylix.colors.base08}";
      misc = "${config.lib.stylix.colors.base03}";
    };
  };
}
