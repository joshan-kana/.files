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
    github-desktop
    gnome.nautilus
    # vscode
    vlc
    youtube-tui
    glow
    ulauncher
    brightnessctl
    jetbrains.pycharm-professional
    floorp
    libreoffice
    onlyoffice-bin
    pavucontrol
  ];

  # My first set of dotfiles
  # git
  programs.git = {
    enable = true;
    userName = "Joshan Kana";
    userEmail = "joshankana@gmail.com";
  };

  # Desktop
  # Compositor: Hyprland
  home.file.".config/hypr/hyprland.conf" = {
    source = ./hyprland/hyprland.conf;
    onChange = "/run/current-system/sw/bin/hyprctl reload";
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
	  format = "{:⎈ %a, %b %d |  %R}";
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
      touch_scroll_multiplier 2.0
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

      # edit hyprland
      hyedit = "code /home/joshan/.config/hypr";

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

  # Text editors
  # Neovim
  programs.neovim = {
    enable = true;
    extraConfig = ''
      autocmd BufRead * autocmd FileType <buffer> ++once
      \ if &ft !~# 'commit\|rebase' && line("'\"") > 1 && line("'\"") <= line("$") | exe 'normal! g`"' | endif
      '';
  };
  programs.vscode.enable = true;
  # programs.vscode.package = (pkgs.vscode.override{ isInsiders = true; }).overrideAttrs (oldAttrs: rec {
  #   src = (builtins.fetchTarball {
  #     url = "https://code.visualstudio.com/sha/download?build=insider&os=linux-x64";
  #     sha256 = "1xhni4bxl0h5i57z78k1xnw6bzp5svbfh20sbb3xga0vsgrm4vkm";
  #   });
  #   version = "latest";
  # });

  # Disabling stylix for vscode
  stylix.targets.vscode.enable = false;


  # Browsers
  # Firefox
  programs.firefox.enable = true;
  # Brave (add to home.packages)

  # Media Players
  programs.mpv.enable = true;

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

  # KDE Plasma
  programs.plasma = {
    enable = true;
    shortcuts = {
      "ActivityManager"."switch-to-activity-8137df4f-6b38-4082-8c6a-350221fd28b0" = [ ];
      "KDE Keyboard Layout Switcher"."Switch to Last-Used Keyboard Layout" = "Meta+Alt+L";
      "KDE Keyboard Layout Switcher"."Switch to Next Keyboard Layout" = "Meta+Alt+K";
      "kaccess"."Toggle Screen Reader On and Off" = [ ];
      "kcm_touchpad"."Disable Touchpad" = "Touchpad Off";
      "kcm_touchpad"."Enable Touchpad" = "Touchpad On";
      "kcm_touchpad"."Toggle Touchpad" = ["Touchpad Toggle" "Meta+Ctrl+Zenkaku Hankaku"];
      "kmix"."decrease_microphone_volume" = "Microphone Volume Down";
      "kmix"."decrease_volume" = "Volume Down";
      "kmix"."decrease_volume_small" = "Shift+Volume Down";
      "kmix"."increase_microphone_volume" = "Microphone Volume Up";
      "kmix"."increase_volume" = "Volume Up";
      "kmix"."increase_volume_small" = "Shift+Volume Up";
      "kmix"."mic_mute" = ["Microphone Mute" "Meta+Volume Mute"];
      "kmix"."mute" = "Volume Mute";
      "ksmserver"."Halt Without Confirmation" = [ ];
      "ksmserver"."Lock Session" = ["Meta+L" "Screensaver"];
      "ksmserver"."Log Out" = "Ctrl+Alt+Del";
      "ksmserver"."Log Out Without Confirmation" = [ ];
      "ksmserver"."Reboot" = [ ];
      "ksmserver"."Reboot Without Confirmation" = [ ];
      "ksmserver"."Shut Down" = [ ];
      "kwin"."Activate Window Demanding Attention" = [ ];
      "kwin"."Cycle Overview" = [ ];
      "kwin"."Cycle Overview Opposite" = [ ];
      "kwin"."Decrease Opacity" = [ ];
      "kwin"."Edit Tiles" = "Meta+T";
      "kwin"."Expose" = "Ctrl+F9";
      "kwin"."ExposeAll" = ["Launch (C)" "Ctrl+F10"];
      "kwin"."ExposeClass" = "Ctrl+F7";
      "kwin"."ExposeClassCurrentDesktop" = [ ];
      "kwin"."Grid View" = "Meta+G";
      "kwin"."Increase Opacity" = [ ];
      "kwin"."Kill Window" = "Meta+Ctrl+Esc";
      "kwin"."Move Tablet to Next Output" = [ ];
      "kwin"."MoveMouseToCenter" = "Meta+F6";
      "kwin"."MoveMouseToFocus" = "Meta+F5";
      "kwin"."MoveZoomDown" = [ ];
      "kwin"."MoveZoomLeft" = [ ];
      "kwin"."MoveZoomRight" = [ ];
      "kwin"."MoveZoomUp" = [ ];
      "kwin"."Overview" = "Meta+Tab";
      "kwin"."PoloniumFocusAbove" = "Meta+W";
      "kwin"."PoloniumFocusBelow" = "Meta+S";
      "kwin"."PoloniumFocusLeft" = "Meta+A";
      "kwin"."PoloniumFocusRight" = "Meta+D";
      "kwin"."PoloniumInsertAbove" = "Meta+Shift+K";
      "kwin"."PoloniumInsertBelow" = "Meta+Shift+J";
      "kwin"."PoloniumInsertLeft" = "Meta+Shift+H";
      "kwin"."PoloniumInsertRight" = "Meta+Shift+L";
      "kwin"."PoloniumOpenSettings" = "Meta+\\,none";
      "kwin"."PoloniumResizeAbove" = "Meta+Shift+W";
      "kwin"."PoloniumResizeBelow" = [ ];
      "kwin"."PoloniumResizeLeft" = "Meta+Shift+A";
      "kwin"."PoloniumResizeRight" = [ ];
      "kwin"."PoloniumRetileWindow" = "Meta+Shift+Space";
      "kwin"."Setup Window Shortcut" = [ ];
      "kwin"."Show Desktop" = [ ];
      "kwin"."Switch One Desktop Down" = "Meta+Ctrl+Down";
      "kwin"."Switch One Desktop Up" = "Meta+Ctrl+Up";
      "kwin"."Switch One Desktop to the Left" = ["Meta+Ctrl+Left" "Meta+Ctrl+A"];
      "kwin"."Switch One Desktop to the Right" = ["Meta+Ctrl+Right" "Meta+Ctrl+D"];
      "kwin"."Switch Window Down" = "Meta+Alt+Down";
      "kwin"."Switch Window Left" = "Meta+Alt+Left";
      "kwin"."Switch Window Right" = "Meta+Alt+Right";
      "kwin"."Switch Window Up" = "Meta+Alt+Up";
      "kwin"."Switch to Desktop 1" = ["Ctrl+F1" "Meta+1"];
      "kwin"."Switch to Desktop 10" = [ ];
      "kwin"."Switch to Desktop 11" = [ ];
      "kwin"."Switch to Desktop 12" = [ ];
      "kwin"."Switch to Desktop 13" = [ ];
      "kwin"."Switch to Desktop 14" = [ ];
      "kwin"."Switch to Desktop 15" = [ ];
      "kwin"."Switch to Desktop 16" = [ ];
      "kwin"."Switch to Desktop 17" = [ ];
      "kwin"."Switch to Desktop 18" = [ ];
      "kwin"."Switch to Desktop 19" = [ ];
      "kwin"."Switch to Desktop 2" = ["Ctrl+F2" "Meta+2"];
      "kwin"."Switch to Desktop 20" = [ ];
      "kwin"."Switch to Desktop 3" = ["Meta+3" "Ctrl+F3"];
      "kwin"."Switch to Desktop 4" = ["Ctrl+F4" "Meta+4"];
      "kwin"."Switch to Desktop 5" = "Meta+5";
      "kwin"."Switch to Desktop 6" = "Meta+6";
      "kwin"."Switch to Desktop 7" = "Meta+7";
      "kwin"."Switch to Desktop 8" = "Meta+8";
      "kwin"."Switch to Desktop 9" = "Meta+9";
      "kwin"."Switch to Next Desktop" = [ ];
      "kwin"."Switch to Next Screen" = [ ];
      "kwin"."Switch to Previous Desktop" = [ ];
      "kwin"."Switch to Previous Screen" = [ ];
      "kwin"."Switch to Screen 0" = [ ];
      "kwin"."Switch to Screen 1" = [ ];
      "kwin"."Switch to Screen 2" = [ ];
      "kwin"."Switch to Screen 3" = [ ];
      "kwin"."Switch to Screen 4" = [ ];
      "kwin"."Switch to Screen 5" = [ ];
      "kwin"."Switch to Screen 6" = [ ];
      "kwin"."Switch to Screen 7" = [ ];
      "kwin"."Switch to Screen Above" = [ ];
      "kwin"."Switch to Screen Below" = [ ];
      "kwin"."Switch to Screen to the Left" = [ ];
      "kwin"."Switch to Screen to the Right" = [ ];
      "kwin"."Toggle Night Color" = [ ];
      "kwin"."Toggle Window Raise/Lower" = [ ];
      "kwin"."TrackMouse" = "Meta+Shift+E";
      "kwin"."Walk Through Windows" = "Alt+Tab";
      "kwin"."Walk Through Windows (Reverse)" = "Alt+Shift+Tab";
      "kwin"."Walk Through Windows Alternative" = [ ];
      "kwin"."Walk Through Windows Alternative (Reverse)" = [ ];
      "kwin"."Walk Through Windows of Current Application" = "Alt+`";
      "kwin"."Walk Through Windows of Current Application (Reverse)" = "Alt+~";
      "kwin"."Walk Through Windows of Current Application Alternative" = [ ];
      "kwin"."Walk Through Windows of Current Application Alternative (Reverse)" = [ ];
      "kwin"."Window Above Other Windows" = [ ];
      "kwin"."Window Below Other Windows" = [ ];
      "kwin"."Window Close" = ["Alt+F4" "Meta+Q"];
      "kwin"."Window Fullscreen" = "Meta+F";
      "kwin"."Window Grow Horizontal" = [ ];
      "kwin"."Window Grow Vertical" = [ ];
      "kwin"."Window Lower" = [ ];
      "kwin"."Window Maximize" = "Meta+PgUp";
      "kwin"."Window Maximize Horizontal" = [ ];
      "kwin"."Window Maximize Vertical" = [ ];
      "kwin"."Window Minimize" = "Meta+PgDown";
      "kwin"."Window Move" = [ ];
      "kwin"."Window Move Center" = [ ];
      "kwin"."Window No Border" = [ ];
      "kwin"."Window On All Desktops" = [ ];
      "kwin"."Window One Desktop Down" = "Meta+Ctrl+Shift+Down";
      "kwin"."Window One Desktop Up" = "Meta+Ctrl+Shift+Up";
      "kwin"."Window One Desktop to the Left" = "Meta+Ctrl+Shift+Left";
      "kwin"."Window One Desktop to the Right" = "Meta+Ctrl+Shift+Right";
      "kwin"."Window One Screen Down" = [ ];
      "kwin"."Window One Screen Up" = [ ];
      "kwin"."Window One Screen to the Left" = [ ];
      "kwin"."Window One Screen to the Right" = [ ];
      "kwin"."Window Operations Menu" = "Alt+F3";
      "kwin"."Window Pack Down" = [ ];
      "kwin"."Window Pack Left" = [ ];
      "kwin"."Window Pack Right" = [ ];
      "kwin"."Window Pack Up" = [ ];
      "kwin"."Window Quick Tile Bottom" = "Meta+Down";
      "kwin"."Window Quick Tile Bottom Left" = [ ];
      "kwin"."Window Quick Tile Bottom Right" = [ ];
      "kwin"."Window Quick Tile Left" = "Meta+Left";
      "kwin"."Window Quick Tile Right" = "Meta+Right";
      "kwin"."Window Quick Tile Top" = "Meta+Up";
      "kwin"."Window Quick Tile Top Left" = [ ];
      "kwin"."Window Quick Tile Top Right" = [ ];
      "kwin"."Window Raise" = [ ];
      "kwin"."Window Resize" = [ ];
      "kwin"."Window Shade" = [ ];
      "kwin"."Window Shrink Horizontal" = [ ];
      "kwin"."Window Shrink Vertical" = [ ];
      "kwin"."Window to Desktop 1" = "Meta+!";
      "kwin"."Window to Desktop 10" = [ ];
      "kwin"."Window to Desktop 11" = [ ];
      "kwin"."Window to Desktop 12" = [ ];
      "kwin"."Window to Desktop 13" = [ ];
      "kwin"."Window to Desktop 14" = [ ];
      "kwin"."Window to Desktop 15" = [ ];
      "kwin"."Window to Desktop 16" = [ ];
      "kwin"."Window to Desktop 17" = [ ];
      "kwin"."Window to Desktop 18" = [ ];
      "kwin"."Window to Desktop 19" = [ ];
      "kwin"."Window to Desktop 2" = "Meta+@";
      "kwin"."Window to Desktop 20" = [ ];
      "kwin"."Window to Desktop 3" = "Meta+#";
      "kwin"."Window to Desktop 4" = "Meta+$";
      "kwin"."Window to Desktop 5" = "Meta+%";
      "kwin"."Window to Desktop 6" = "Meta+^";
      "kwin"."Window to Desktop 7" = "Meta+&";
      "kwin"."Window to Desktop 8" = "Meta+*";
      "kwin"."Window to Desktop 9" = "Meta+(";
      "kwin"."Window to Next Desktop" = [ ];
      "kwin"."Window to Next Screen" = "Meta+Shift+Right";
      "kwin"."Window to Previous Desktop" = [ ];
      "kwin"."Window to Previous Screen" = "Meta+Shift+Left";
      "kwin"."Window to Screen 0" = [ ];
      "kwin"."Window to Screen 1" = [ ];
      "kwin"."Window to Screen 2" = [ ];
      "kwin"."Window to Screen 3" = [ ];
      "kwin"."Window to Screen 4" = [ ];
      "kwin"."Window to Screen 5" = [ ];
      "kwin"."Window to Screen 6" = [ ];
      "kwin"."Window to Screen 7" = [ ];
      "kwin"."view_actual_size" = "Meta+0";
      "kwin"."view_zoom_in" = ["Meta++" "Meta+="];
      "kwin"."view_zoom_out" = "Meta+-";
      "mediacontrol"."mediavolumedown" = [ ];
      "mediacontrol"."mediavolumeup" = [ ];
      "mediacontrol"."nextmedia" = ["Media Next" "Meta+Alt+C"];
      "mediacontrol"."pausemedia" = "Media Pause";
      "mediacontrol"."playmedia" = [ ];
      "mediacontrol"."playpausemedia" = ["Meta+Alt+X" "Media Play"];
      "mediacontrol"."previousmedia" = ["Media Previous" "Meta+Alt+Z"];
      "mediacontrol"."stopmedia" = "Media Stop";
      "org_kde_powerdevil"."Decrease Keyboard Brightness" = "Keyboard Brightness Down";
      "org_kde_powerdevil"."Decrease Screen Brightness" = "Monitor Brightness Down";
      "org_kde_powerdevil"."Decrease Screen Brightness Small" = "Shift+Monitor Brightness Down";
      "org_kde_powerdevil"."Hibernate" = "Hibernate";
      "org_kde_powerdevil"."Increase Keyboard Brightness" = "Keyboard Brightness Up";
      "org_kde_powerdevil"."Increase Screen Brightness" = "Monitor Brightness Up";
      "org_kde_powerdevil"."Increase Screen Brightness Small" = "Shift+Monitor Brightness Up";
      "org_kde_powerdevil"."PowerDown" = "Power Down";
      "org_kde_powerdevil"."PowerOff" = "Power Off";
      "org_kde_powerdevil"."Sleep" = "Sleep";
      "org_kde_powerdevil"."Toggle Keyboard Backlight" = "Keyboard Light On/Off";
      "org_kde_powerdevil"."Turn Off Screen" = [ ];
      "org_kde_powerdevil"."powerProfile" = ["Battery" "Meta+B"];
      "plasmashell"."activate task manager entry 1" = [ ];
      "plasmashell"."activate task manager entry 10" = [ ];
      "plasmashell"."activate task manager entry 2" = [ ];
      "plasmashell"."activate task manager entry 3" = [ ];
      "plasmashell"."activate task manager entry 4" = [ ];
      "plasmashell"."activate task manager entry 5" = [ ];
      "plasmashell"."activate task manager entry 6" = [ ];
      "plasmashell"."activate task manager entry 7" = [ ];
      "plasmashell"."activate task manager entry 8" = [ ];
      "plasmashell"."activate task manager entry 9" = [ ];
      "plasmashell"."clear-history" = [ ];
      "plasmashell"."clipboard_action" = "Meta+Ctrl+X";
      "plasmashell"."cycle-panels" = "Meta+Alt+P";
      "plasmashell"."cycleNextAction" = [ ];
      "plasmashell"."cyclePrevAction" = [ ];
      "plasmashell"."manage activities" = [ ];
      "plasmashell"."next activity" = [ ];
      "plasmashell"."previous activity" = [ ];
      "plasmashell"."repeat_action" = [ ];
      "plasmashell"."show dashboard" = "Ctrl+F12";
      "plasmashell"."show-barcode" = [ ];
      "plasmashell"."show-on-mouse-pos" = "Meta+V";
      "plasmashell"."stop current activity" = [ ];
      "plasmashell"."switch to next activity" = [ ];
      "plasmashell"."switch to previous activity" = [ ];
      "plasmashell"."toggle do not disturb" = [ ];
      "services.org.kde.spectacle.desktop"."_launch" = "Print";
      "services.playerctl-2.desktop"."_launch" = "Meta+Alt+S";
      "services.playerctl.desktop"."_launch" = "Meta+Alt+D";
      "services.playerctld.desktop"."_launch" = "Meta+Alt+F";
    };
    configFile = {
      "dolphinrc"."KFileDialog Settings"."Places Icons Auto-resize" = false;
      "dolphinrc"."KFileDialog Settings"."Places Icons Static Size" = 22;
      "kactivitymanagerdrc"."activities"."8137df4f-6b38-4082-8c6a-350221fd28b0" = "Default";
      "kactivitymanagerdrc"."main"."currentActivity" = "8137df4f-6b38-4082-8c6a-350221fd28b0";
      "kcminputrc"."Keyboard"."RepeatDelay" = 300;
      "kcminputrc"."Libinput.1133.16478.Logitech M720 Triathlon"."PointerAcceleration" = 0.200;
      "kcminputrc"."Libinput.1133.16478.Logitech M720 Triathlon"."PointerAccelerationProfile" = 1;
      "kcminputrc"."Libinput.1133.16478.Logitech M720 Triathlon"."ScrollFactor" = 1;
      "kded5rc"."Module-device_automounter"."autoload" = false;
      "kdeglobals"."KDE"."AnimationDurationFactor" = 0.5;
      "kdeglobals"."KFileDialog Settings"."Allow Expansion" = false;
      "kdeglobals"."KFileDialog Settings"."Automatically select filename extension" = true;
      "kdeglobals"."KFileDialog Settings"."Breadcrumb Navigation" = true;
      "kdeglobals"."KFileDialog Settings"."Decoration position" = 2;
      "kdeglobals"."KFileDialog Settings"."LocationCombo Completionmode" = 5;
      "kdeglobals"."KFileDialog Settings"."PathCombo Completionmode" = 5;
      "kdeglobals"."KFileDialog Settings"."Show Bookmarks" = false;
      "kdeglobals"."KFileDialog Settings"."Show Full Path" = false;
      "kdeglobals"."KFileDialog Settings"."Show Inline Previews" = true;
      "kdeglobals"."KFileDialog Settings"."Show Preview" = false;
      "kdeglobals"."KFileDialog Settings"."Show Speedbar" = true;
      "kdeglobals"."KFileDialog Settings"."Show hidden files" = false;
      "kdeglobals"."KFileDialog Settings"."Sort by" = "Name";
      "kdeglobals"."KFileDialog Settings"."Sort directories first" = true;
      "kdeglobals"."KFileDialog Settings"."Sort hidden files last" = false;
      "kdeglobals"."KFileDialog Settings"."Sort reversed" = false;
      "kdeglobals"."KFileDialog Settings"."Speedbar Width" = 190;
      "kdeglobals"."KFileDialog Settings"."View Style" = "DetailTree";
      "kdeglobals"."Shortcuts"."Quit" = "Ctrl+Shift+Q";
      "kdeglobals"."WM"."activeBackground" = "29,32,33";
      "kdeglobals"."WM"."activeBlend" = "250,189,47";
      "kdeglobals"."WM"."activeForeground" = "213,196,161";
      "kdeglobals"."WM"."inactiveBackground" = "29,32,33";
      "kdeglobals"."WM"."inactiveBlend" = "102,92,84";
      "kdeglobals"."WM"."inactiveForeground" = "213,196,161";
      "kglobalshortcutsrc"."ActivityManager"."_k_friendly_name" = "Activity Manager";
      "kglobalshortcutsrc"."KDE Keyboard Layout Switcher"."_k_friendly_name" = "Keyboard Layout Switcher";
      "kglobalshortcutsrc"."kaccess"."_k_friendly_name" = "Accessibility";
      "kglobalshortcutsrc"."kcm_touchpad"."_k_friendly_name" = "Touchpad";
      "kglobalshortcutsrc"."kmix"."_k_friendly_name" = "Audio Volume";
      "kglobalshortcutsrc"."ksmserver"."_k_friendly_name" = "Session Management";
      "kglobalshortcutsrc"."kwin"."_k_friendly_name" = "System Settings";
      "kglobalshortcutsrc"."mediacontrol"."_k_friendly_name" = "Media Controller";
      "kglobalshortcutsrc"."org_kde_powerdevil"."_k_friendly_name" = "KDE Power Management System";
      "kglobalshortcutsrc"."plasmashell"."_k_friendly_name" = "plasmashell";
      "krunnerrc"."General"."FreeFloating" = true;
      "kwalletrc"."Wallet"."First Use" = false;
      "kwinrc"."Desktops"."Id_1" = "6b9fb101-cf8d-45bc-8491-eedd5963bcfc";
      "kwinrc"."Desktops"."Id_2" = "fd56cfe0-be24-4029-9694-5235d51ae552";
      "kwinrc"."Desktops"."Id_3" = "0ddd6e83-d9b4-4f3e-9989-899ff0af0cec";
      "kwinrc"."Desktops"."Id_4" = "3c782741-2746-4eeb-9a68-3802895ffafa";
      "kwinrc"."Desktops"."Id_5" = "ed5ed2f1-417f-4ea7-99f6-473e72ef5c51";
      "kwinrc"."Desktops"."Id_6" = "7b31bf4b-eb14-470b-96b6-7b1718df83b1";
      "kwinrc"."Desktops"."Id_7" = "e33580f6-e56d-4d98-b3a7-7a750ccb3aea";
      "kwinrc"."Desktops"."Id_8" = "99ecae0b-098f-4600-b98f-2685af293ef6";
      "kwinrc"."Desktops"."Id_9" = "4fe209f5-a35d-46d4-825c-b4ceb53ac2b7";
      "kwinrc"."Desktops"."Number" = 9;
      "kwinrc"."Desktops"."Rows" = 1;
      "kwinrc"."Effect-kwin4_effect_geometry_change"."Duration" = 750;
      "kwinrc"."Effect-slide"."SlideBackground" = false;
      "kwinrc"."Effect-trackmouse"."Control" = false;
      "kwinrc"."Effect-trackmouse"."Shift" = true;
      "kwinrc"."Plugins"."desktopchangeosdEnabled" = false;
      "kwinrc"."Plugins"."kwin4_effect_geometry_changeEnabled" = true;
      "kwinrc"."Plugins"."poloniumEnabled" = false;
      "kwinrc"."Script-polonium"."InsertionPoint" = 2;
      "kwinrc"."Script-polonium"."KeepTiledBelow" = false;
      "kwinrc"."Script-polonium"."ResizeAmount" = 17;
      "kwinrc"."Tiling"."padding" = 8;
      "kwinrc"."Tiling.f3244e44-4004-5526-a53a-152fabf66ecd"."tiles" = "{\"layoutDirection\":\"horizontal\",\"tiles\":[]}";
      "kwinrc"."Tiling.f543e7f1-a9ce-5e64-8a9b-f1bdd336dd8e"."tiles" = "{\"layoutDirection\":\"horizontal\",\"tiles\":[]}";
      "kwinrc"."Windows"."DelayFocusInterval" = 0;
      "kwinrc"."Windows"."FocusPolicy" = "FocusFollowsMouse";
      "kwinrc"."Xwayland"."Scale" = 1.5;
      "kwinrulesrc"."1"."Description" = "Remove title bars";
      "kwinrulesrc"."1"."noborderrule" = 2;
      "kwinrulesrc"."69a128b7-0ade-4a81-98e2-acb107feec52"."Description" = "Remove title bars";
      "kwinrulesrc"."69a128b7-0ade-4a81-98e2-acb107feec52"."noborderrule" = 2;
      "kwinrulesrc"."General"."count" = 1;
      "kwinrulesrc"."General"."rules" = 1;
      "plasma-localerc"."Formats"."LANG" = "en_GB.UTF-8";
      "plasma-localerc"."Formats"."LC_MONETARY" = "en_AU.UTF-8";
      "plasma-localerc"."Formats"."LC_TELEPHONE" = "en_AU.UTF-8";
      "systemsettingsrc"."KFileDialog Settings"."detailViewIconSize" = 16;
    };
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
