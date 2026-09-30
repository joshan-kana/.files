{
  config,
  lib,
  pkgs,
  ...
}:

let
  xwaylandEnabled = true;
  terminal = config.dotfiles.defaults.terminal;
in
{
  programs.hyprland.xwayland.enable = xwaylandEnabled;
  environment.sessionVariables.WLR_NO_HARDWARE_CURSORS = "1";

  eww = _: {
    home = _: {
      programs.eww = {
        yuckConfig = builtins.readFile ./eww/eww.yuck;
        scssConfig = builtins.readFile ./eww/eww.scss;
      };
    };
  };

  wofi = _: {
    home = _: {
      programs.wofi.settings = {
        allow_images = true;
        matching = "fuzzy";
      };
    };
  };

  rofi = _: {
    home = _: {
      programs.rofi = {
        settings.terminal = terminal;
        plugins = with pkgs; [ rofi-calc ];
      };
    };
  };

  tofi = _: {
    home = { config, ... }: {
      home.packages = [ pkgs.tofi ];
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
    };
  };

  waybar = _: {
    home = _: {
      programs.waybar.settings.mainBar = {
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
          on-scroll-up = "hyprctl dispatch 'hl.dsp.focus({ workspace = \"e+1\" })'";
          on-scroll-down = "hyprctl dispatch 'hl.dsp.focus({ workspace = \"e-1\" })'";
        };
        mpris = {
          interval = 1;
          format = "{player}: {status_icon} {position}/{length}";
          status-icons = {
            playing = "▶";
            paused = "⏸";
          };
        };
        clock.format = "⎈ {:%a, %b %d |  %R}";
        backlight = {
          format = "{percent}% {icon}";
          format-icons = [
            ""
            ""
          ];
          scroll-step = 0.35;
        };
        battery = {
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
        wireplumber = {
          format = "{volume}% {icon}";
          format-icons = [
            ""
            ""
            ""
          ];
          scroll-step = 0.35;
        };
        tray.spacing = 10;
      };
    };
  };

  swaylock = _: {
    security.pam.services.swaylock = { };

    home = _: {
      programs.swaylock.package = pkgs.swaylock-effects;
    };
  };

  cliphist = _: {
    home = _: {
      services.cliphist = { };
    };
  };

  avizo = _: {
    home = _: {
      services.avizo.settings.default = {
        time = 1.0;
        fade-in = 0.1;
        fade-out = 0.2;
        padding = 10;
      };
    };
  };

  home = _: {
    home.packages = with pkgs; [
      wl-clipboard
      brightnessctl
      polkit_gnome
      awww
      networkmanagerapplet
      playerctl
      grimblast
      nwg-panel
      nwg-dock-hyprland
      nwg-displays
      wlr-randr
    ];

    # disable hyprpaper target to prevent crash loops
    stylix.targets.hyprland.hyprpaper.enable = false;

    home.shellAliases = {
      h = "start-hyprland";
      HI = "${config.dotfiles.paths.repoPath}/scripts/hyprland_intel";
      HN = "${config.dotfiles.paths.repoPath}/scripts/hyprland_nvidia";
    };

    wayland.windowManager.hyprland =
      let
        lua = lib.generators.mkLuaInline;
        mod = keys: lua ''mainMod .. " + ${keys}"'';
        bind = keys: dispatcher: {
          _args = [
            keys
            (lua dispatcher)
          ];
        };
        bindWith = keys: dispatcher: flags: {
          _args = [
            keys
            (lua dispatcher)
            flags
          ];
        };
        modBind = keys: dispatcher: bind (mod keys) dispatcher;
        exec = command: ''hl.dsp.exec_cmd("${command}")'';
        keybindings = import ./keybindings.nix {
          repoPath = config.dotfiles.paths.repoPath;
          inherit terminal;
        };
        actionDispatcher =
          action:
          if action.type == "exec" then
            exec action.value
          else if action.type == "global" then
            ''hl.dsp.global("${action.value}")''
          else
            action.value;
        renderBinding =
          binding:
          let
            keys = if binding.mainMod then mod binding.keys else binding.keys;
            dispatcher = actionDispatcher binding.action;
          in
          if binding.flags == { } then bind keys dispatcher else bindWith keys dispatcher binding.flags;
      in
      {
        xwayland.enable = xwaylandEnabled;
        configType = "lua";

        settings = {
          mainMod._var = "SUPER";

          config = {
            xwayland.force_zero_scaling = true;

            input = {
              kb_layout = "us";
              kb_variant = "";
              kb_model = "";
              kb_options = "";
              kb_rules = "";
              repeat_rate = 35;
              repeat_delay = 225;
              follow_mouse = 1;
              accel_profile = "flat";
              sensitivity = 0.5;

              touchpad = {
                natural_scroll = true;
                scroll_factor = 0.2;
                tap_to_click = true;
                tap_and_drag = true;
              };
            };

            general = {
              gaps_in = 5;
              gaps_out = 15;
              border_size = 0;
              layout = "dwindle";
              allow_tearing = false;
            };

            decoration = {
              rounding = 10;

              blur = {
                enabled = true;
                size = 3;
                passes = 1;
              };

              shadow = {
                enabled = true;
                range = 30;
                render_power = 3;
              };
            };

            animations.enabled = true;
            dwindle.preserve_split = true;
            master.new_status = "slave";

            misc = {
              force_default_wallpaper = 0;
              disable_hyprland_logo = true;
              disable_splash_rendering = true;
              enable_swallow = true;
              swallow_regex = "^(${lib.escapeRegex terminal})$";
              focus_on_activate = true;
            };
          };

          curve = {
            _args = [
              "myBezier"
              {
                type = "bezier";
                points = [
                  [
                    0.05
                    0.9
                  ]
                  [
                    0.1
                    1.05
                  ]
                ];
              }
            ];
          };

          animation = [
            {
              leaf = "windows";
              enabled = true;
              speed = 4;
              bezier = "myBezier";
            }
            {
              leaf = "windowsOut";
              enabled = true;
              speed = 4;
              bezier = "default";
              style = "popin 80%";
            }
            {
              leaf = "border";
              enabled = true;
              speed = 4;
              bezier = "default";
            }
            {
              leaf = "borderangle";
              enabled = true;
              speed = 4;
              bezier = "default";
            }
            {
              leaf = "fade";
              enabled = true;
              speed = 4;
              bezier = "default";
            }
            {
              leaf = "workspaces";
              enabled = true;
              speed = 4;
              bezier = "default";
            }
            {
              leaf = "specialWorkspace";
              enabled = true;
              speed = 4;
              bezier = "default";
              style = "slidefadevert 20%";
            }
          ];

          gesture = {
            fingers = 3;
            direction = "horizontal";
            action = "workspace";
          };

          device = {
            name = "epic-mouse-v1";
            sensitivity = -0.5;
          };

          window_rule = {
            match.class = "polkit-kde-authentication-agent-1";
            float = true;
            center = true;
            size = [
              500
              250
            ];
          };

          on = {
            _args = [
              "hyprland.start"
              (lua ''
                function()
                  hl.exec_cmd("awww-daemon && awww img ~/.config/home-manager/wallpaper.png")
                  hl.exec_cmd("waybar")
                  hl.exec_cmd("nm-applet --indicator")
                  hl.exec_cmd("dunst")
                  hl.exec_cmd("avizo-service")
                  hl.exec_cmd("wl-paste --type text --watch cliphist store")
                  hl.exec_cmd("wl-paste --type image --watch cliphist store")
                  hl.exec_cmd("playerctld daemon")
                  hl.exec_cmd("dropbox")
                  hl.exec_cmd("${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1")
                end
              '')
            ];
          };

          bind = map renderBinding keybindings;
        };

        submaps.passthru.settings.bind = [
          (modBind "SHIFT + Escape" ''hl.dsp.submap("reset")'')
        ];

        # nwg-displays writes ~/.config/hypr/monitors.lua for Hyprland 0.55+.
        extraConfig = ''
          local configHome = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
          local monitorsFile = io.open(configHome .. "/hypr/monitors.lua", "r")
          if monitorsFile then
            monitorsFile:close()
            require("monitors")
          end
        '';
      };
  };
}
