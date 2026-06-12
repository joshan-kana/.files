{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  cfg = osConfig.dotfiles;
  primaryHome = "${cfg.users.primary.homeRoot}/${cfg.users.primary.name}";
in
lib.mkIf cfg.features.desktop.enable {
  programs.eww = {
    enable = true;
    package = pkgs.eww;
    configDir = ../../desktop/eww;
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

  gtk = {
    iconTheme = {
      package = pkgs.gruvbox-dark-icons-gtk;
      name = "oomox-gruvbox-dark";
    };
  };

}
