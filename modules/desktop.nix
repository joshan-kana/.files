{
  config,
  inputs,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles;
  primaryHome = "${cfg.users.primary.homeRoot}/${cfg.users.primary.name}";
in
{

  boot = import ./nixos/boot.nix;
  ssh = import ./nixos/ssh.nix;
  vpn = import ./nixos/vpn.nix;
  displayManager = import ../desktop/display-manager.nix;
  hyprland = import ../desktop/hyprland;
  plasma = import ../desktop/plasma;

  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10"
  ];

  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = false;
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  fonts =
    let
      nerdSymbols =
        if builtins.hasAttr "nerd-fonts" pkgs then
          pkgs."nerd-fonts".symbols-only
        else
          (pkgs.nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; });
    in
    {
      packages = [
        config.stylix.fonts.monospace.package
        config.stylix.fonts.emoji.package
        nerdSymbols
      ];

      fontconfig.defaultFonts = {
        monospace = [
          config.stylix.fonts.monospace.name
          "Symbols Nerd Font Mono"
          "Symbols Nerd Font"
        ];
        sansSerif = [ config.stylix.fonts.sansSerif.name ];
        serif = [ config.stylix.fonts.serif.name ];
        emoji = [ config.stylix.fonts.emoji.name ];
      };
    };

  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    KWIN_FORCE_SW_CURSOR = "1";
    NIXOS_OZONE_WL = "1";
    EDITOR = "nvim";
  };

  virtualisation.docker.enable = true;
  users.users.${config.dotfiles.users.primary.name}.extraGroups = [
    "docker"
    "libvirtd"
  ];
  virtualisation.libvirtd = {
    enable = true;
    qemu.swtpm.enable = true;
  };
  programs.virt-manager.enable = true;
  security.polkit.enable = true;
  services.gvfs.enable = true;

  security.pam.services.swaylock = { };

  environment.systemPackages = with pkgs; [
    chromium
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta
    waypipe
    sunshine
    thunderbird
    obsidian
    kdePackages.filelight
    gimp
    stow
    qjackctl
    xdg-utils
    wl-clipboard
    quickemu
    killall
    gparted
    moonlight-qt
    distrobox
    bottles
    mullvad-vpn
    github-desktop
    nautilus
    vlc
    youtube-tui
    brightnessctl
    jetbrains.pycharm
    libreoffice
    pavucontrol
    python3
    trash-cli
    gnumake
    devbox
    has
    waybar
    polkit_gnome
    awww
    networkmanagerapplet
    playerctl
    grimblast
    nwg-panel
    nwg-dock-hyprland
    nwg-displays
    wlr-randr
    tofi
    nvd
    nix-tree
    gh
  ];

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };
  services.pulseaudio.enable = false;

  networking.firewall.allowedTCPPorts = [
    22
    47990
    11434
    11435
  ];

  home = { config, ... }: {
    programs.eww = {
      enable = true;
      package = pkgs.eww;
      yuckConfig = builtins.readFile ../desktop/eww/eww.yuck;
      scssConfig = builtins.readFile ../desktop/eww/eww.scss;
    };

    programs.wofi = {
      enable = true;
      settings = {
        allow_images = true;
        matching = "fuzzy";
      };
    };

    programs.rofi = {
      enable = true;
      package = pkgs.rofi;
      terminal = "kitty";
      plugins = with pkgs; [ rofi-calc ];
    };

    home.file.".config/tofi/config".text = ''
      font = ${config.stylix.fonts.monospace.name}
      font-size = 18
      background-color = #${config.lib.stylix.colors.base00}
      text-color = #${config.lib.stylix.colors.base07}
      selection-color = #${config.lib.stylix.colors.base0A}
      width = 45%
      height = 35%
      border-width = 5
      border-color = #${config.lib.stylix.colors.base03}
      corner-radius = 20
    '';

    programs.waybar = {
      enable = true;
      settings.mainBar = {
        layer = "top";
        spacing = 10;
        modules-left = [
          "hyprland/workspaces"
          "mpris"
        ];
        modules-center = [ "clock" ];
        modules-right = [
          "backlight"
          "wireplumber"
          "battery"
          "tray"
        ];
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
        "clock".format = "⎈ {:%a, %b %d |  %R}";
        "backlight" = {
          format = "{percent}% {icon}";
          format-icons = [
            ""
            ""
          ];
          scroll-step = 0.35;
        };
        "battery" = {
          interval = 120;
          format = "{capacity}% {icon}";
          format-icons = [
            ""
            ""
            ""
            ""
            ""
          ];
        };
        "wireplumber" = {
          format = "{volume}% {icon}";
          format-icons = [
            ""
            ""
            ""
          ];
          scroll-step = 0.35;
        };
        "tray".spacing = 10;
      };
    };

    programs.swaylock = {
      enable = true;
      package = pkgs.swaylock-effects;
    };

    services.cliphist.enable = true;
    services.dunst = {
      enable = true;
      settings.global = {
        mouse_right_click = "do_action";
        dmenu = "${primaryHome}/.nix-profile/bin/rofi -dmenu";
      };
    };
    services.avizo = {
      enable = true;
      settings.default = {
        time = 1.0;
        fade-in = 0.1;
        fade-out = 0.2;
        padding = 10;
      };
    };
    services.easyeffects.enable = true;

    programs.kitty = {
      enable = true;
      extraConfig = ''
        confirm_os_window_close 0
        enable_audio_bell no
        input_delay 0
        touch_scroll_multiplier 3.0
      '';
    };
    programs.alacritty.enable = true;

    programs.vscode.enable = true;

    programs.firefox.enable = true;
    stylix.targets.firefox.profileNames = [ "themed" ];
    stylix.targets.firefox.colorTheme.enable = true;
    programs.firefox.profiles.themed.extensions.force = true;
    programs.firefox.configPath = ".mozilla/firefox";

    programs.floorp.enable = true;
    stylix.targets.floorp.profileNames = [ "themed" ];
    stylix.targets.floorp.colorTheme.enable = true;
    programs.floorp.profiles.themed.extensions.force = true;

    services.mopidy = {
      enable = false;
      extensionPackages = with pkgs; [
        mopidy-mpd
        mopidy-mpris
      ];
      settings.mpd = {
        enabled = true;
        hostname = "127.0.0.1";
        port = "6600";
      };
    };

    programs.ncmpcpp = {
      enable = true;
      package = pkgs.ncmpcpp.override { visualizerSupport = true; };
    };

    programs.cava = {
      enable = true;
      settings = {
        general.lower_cutoff_freq = 20;
        general.upper_cutoff_freq = 20000;
        smoothing.noise_reduction = 30;
        smoothing.monstercat = 1;
        general.bar_width = 1;
        general.bar_spacing = 0;
        output.channels = "mono";
        color.gradient = 1;
        color.gradient_count = 8;
        color.gradient_color_1 = "'#${config.lib.stylix.colors.base01}'";
        color.gradient_color_2 = "'#${config.lib.stylix.colors.base02}'";
        color.gradient_color_3 = "'#${config.lib.stylix.colors.base03}'";
        color.gradient_color_4 = "'#${config.lib.stylix.colors.base04}'";
        color.gradient_color_5 = "'#${config.lib.stylix.colors.base05}'";
        color.gradient_color_6 = "'#${config.lib.stylix.colors.base06}'";
        color.gradient_color_7 = "'#${config.lib.stylix.colors.base07}'";
        color.gradient_color_8 = "'#${config.lib.stylix.colors.base08}'";
      };
    };

  };
}
