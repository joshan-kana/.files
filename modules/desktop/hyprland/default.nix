{
  config,
  lib,
  pkgs,
  ...
}:

let
  xwaylandEnabled = true;
  terminal = config.dotfiles.defaults.terminal;
  aliases = {
    h = "start-hyprland";
    HI = "${config.dotfiles.paths.repoPath}/scripts/hyprland_intel";
    HN = "${config.dotfiles.paths.repoPath}/scripts/hyprland_nvidia";
  };
in
{
  environment.shellAliases = aliases;
  programs.hyprland.xwayland.enable = xwaylandEnabled;
  environment.sessionVariables.WLR_NO_HARDWARE_CURSORS = "1";

  environment.systemPackages = with pkgs; [
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

  shell = import ./shell;

  eww = _: {
    home = _: {
      programs.eww = {
        package = pkgs.eww;
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
        package = pkgs.rofi;
        settings.terminal = terminal;
        plugins = with pkgs; [ rofi-calc ];
      };
    };
  };

  tofi = _: {
    environment.systemPackages = [ pkgs.tofi ];

    home = { config, ... }: {
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

  dunst = _: {
    home = { config, ... }: {
      services.dunst.settings.global = {
        mouse_right_click = "do_action";
        dmenu = "${config.home.homeDirectory}/.nix-profile/bin/rofi -dmenu";
      };
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
    # disable hyprpaper target to prevent crash loops
    stylix.targets.hyprland.hyprpaper.enable = false;

    home.shellAliases = aliases;

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
        modBindWith =
          keys: dispatcher: flags:
          bindWith (mod keys) dispatcher flags;
        exec = command: ''hl.dsp.exec_cmd("${command}")'';
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

          bind = [
            # Favourite apps
            (modBind "ALT + 1" (exec terminal))
            (modBind "ALT + 2" (exec "spotify"))
            (modBind "ALT + 3" (exec "brave"))
            (modBind "ALT + 4" (exec "floorp"))
            (modBind "ALT + 5" (exec "thunderbird"))
            (modBind "ALT + 6" (exec "code"))
            (modBind "ALT + 7" (exec "obsidian --disable-gpu"))
            (modBind "ALT + E" (exec "nautilus"))
            (modBind "SHIFT + V" (exec "${config.dotfiles.paths.repoPath}/scripts/volume_mixer"))
            (modBind "ALT + V" (exec "${config.dotfiles.paths.repoPath}/scripts/audio_fx"))

            # Applets and launchers
            (modBind "SPACE" (exec "${config.dotfiles.paths.repoPath}/scripts/app_launch"))
            (modBind "V" (exec "cliphist list | tofi | cliphist decode | wl-copy"))
            (bind "ALT + SPACE" (exec "~/repos/rofi-desktop/scripts/rofi-desktop.sh"))

            # Window management
            (modBind "Q" "hl.dsp.window.close()")
            (modBind "M" "hl.dsp.exit()")
            (modBind "SHIFT + F" "hl.dsp.window.float()")
            (modBind "SHIFT + P" "hl.dsp.window.pin()")
            (modBind "P" "hl.dsp.window.pseudo()")
            (modBind "J" ''hl.dsp.layout("togglesplit")'')
            (modBind "F" ''hl.dsp.window.fullscreen({ mode = "maximized" })'')
            (modBindWith "mouse:272" "hl.dsp.window.drag()" { mouse = true; })
            (modBindWith "mouse:273" "hl.dsp.window.resize()" { mouse = true; })

            # Focus
            (modBind "A" ''hl.dsp.focus({ direction = "l" })'')
            (modBind "D" ''hl.dsp.focus({ direction = "r" })'')
            (modBind "W" ''hl.dsp.focus({ direction = "u" })'')
            (modBind "S" ''hl.dsp.focus({ direction = "d" })'')

            # Workspaces
            (modBind "1" ''hl.dsp.focus({ workspace = "1" })'')
            (modBind "2" ''hl.dsp.focus({ workspace = "2" })'')
            (modBind "3" ''hl.dsp.focus({ workspace = "3" })'')
            (modBind "4" ''hl.dsp.focus({ workspace = "4" })'')
            (modBind "5" ''hl.dsp.focus({ workspace = "5" })'')
            (modBind "6" ''hl.dsp.focus({ workspace = "6" })'')
            (modBind "7" ''hl.dsp.focus({ workspace = "7" })'')
            (modBind "8" ''hl.dsp.focus({ workspace = "8" })'')
            (modBind "9" ''hl.dsp.focus({ workspace = "9" })'')
            (modBind "0" ''hl.dsp.focus({ workspace = "10" })'')

            (modBind "SHIFT + 1" ''hl.dsp.window.move({ workspace = "1", follow = false })'')
            (modBind "SHIFT + 2" ''hl.dsp.window.move({ workspace = "2", follow = false })'')
            (modBind "SHIFT + 3" ''hl.dsp.window.move({ workspace = "3", follow = false })'')
            (modBind "SHIFT + 4" ''hl.dsp.window.move({ workspace = "4", follow = false })'')
            (modBind "SHIFT + 5" ''hl.dsp.window.move({ workspace = "5", follow = false })'')
            (modBind "SHIFT + 6" ''hl.dsp.window.move({ workspace = "6", follow = false })'')
            (modBind "SHIFT + 7" ''hl.dsp.window.move({ workspace = "7", follow = false })'')
            (modBind "SHIFT + 8" ''hl.dsp.window.move({ workspace = "8", follow = false })'')
            (modBind "SHIFT + 9" ''hl.dsp.window.move({ workspace = "9", follow = false })'')
            (modBind "SHIFT + 0" ''hl.dsp.window.move({ workspace = "10", follow = false })'')

            (modBindWith "SHIFT + D" "hl.dsp.window.resize({ x = 50, y = 0, relative = true })" {
              repeating = true;
            })
            (modBindWith "SHIFT + A" "hl.dsp.window.resize({ x = -50, y = 0, relative = true })" {
              repeating = true;
            })
            (modBindWith "SHIFT + W" "hl.dsp.window.resize({ x = 0, y = -50, relative = true })" {
              repeating = true;
            })
            (modBindWith "SHIFT + S" "hl.dsp.window.resize({ x = 0, y = 50, relative = true })" {
              repeating = true;
            })

            (modBind "X" ''hl.dsp.workspace.toggle_special("magic")'')
            (modBind "SHIFT + X" ''hl.dsp.window.move({ workspace = "special:magic", follow = true })'')
            (modBind "mouse_down" ''hl.dsp.focus({ workspace = "e+1" })'')
            (modBind "mouse_up" ''hl.dsp.focus({ workspace = "e-1" })'')
            (modBind "CTRL + A" ''hl.dsp.focus({ workspace = "e-1" })'')
            (modBind "CTRL + D" ''hl.dsp.focus({ workspace = "e+1" })'')

            # Media keys
            (bindWith "XF86AudioRaiseVolume" (exec "volumectl + 5") { repeating = true; })
            (bindWith "XF86AudioLowerVolume" (exec "volumectl - 5") { repeating = true; })
            (bind "XF86AudioMute" (exec "volumectl %"))
            (modBind "ALT + X" (exec "playerctl play-pause"))
            (modBind "ALT + C" (exec "playerctl next"))
            (modBind "ALT + Z" (exec "playerctl previous"))
            (modBindWith "ALT + D" (exec "playerctl position 10+") { repeating = true; })
            (modBindWith "ALT + S" (exec "playerctl position 10-") { repeating = true; })
            (modBind "ALT + W" (exec "playerctl shuffle toggle"))
            (modBind "ALT + F" (exec "playerctld shift"))

            # Brightness
            (bindWith "XF86MonBrightnessUp" (exec "lightctl + 5") { repeating = true; })
            (bindWith "XF86MonBrightnessDown" (exec "lightctl - 5") { repeating = true; })

            (modBind "L" (exec "swaylock"))
            (modBind "SHIFT + E" (exec "code ${config.dotfiles.paths.repoPath}/edit_config.code-workspace"))
            (modBind "Escape" ''hl.dsp.submap("passthru")'')
          ];
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
