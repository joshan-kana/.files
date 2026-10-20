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

  lock = _: {
    security.pam.services.linux-desktop = { };
  };

  cliphist = _: {
    home = _: {
      services.cliphist = { };
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
        meh = keys: lua ''mehMod .. " + ${keys}"'';
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
          inherit terminal;
        };
        globalKeybindings = lib.filter (binding: binding.submap == null) keybindings;
        launcherKeybindings = lib.filter (binding: binding.submap == "launcher") keybindings;
        resizeKeybindings = lib.filter (binding: binding.submap == "resize") keybindings;
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
            keys =
              if binding.mehMod then
                meh binding.keys
              else if binding.mainMod then
                mod binding.keys
              else
                binding.keys;
            dispatcher = actionDispatcher binding.action;
          in
          if binding.flags == { } then bind keys dispatcher else bindWith keys dispatcher binding.flags;
      in
      {
        xwayland.enable = xwaylandEnabled;
        configType = "lua";

        settings = {
          mainMod._var = "SUPER";
          mehMod._var = "CTRL + ALT + SHIFT";

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
              # Modal layer dimming should be subtle, not the compositor's
              # heavy 0.4 default. Authentication has its own themed scrim.
              dim_around = 0.12;
              dim_special = 0.12;

              blur = {
                enabled = true;
                size = 8;
                passes = 2;
                special = true;
              };

              shadow = {
                enabled = true;
                range = 18;
                render_power = 2;
                color = lib.mkForce "rgba(${config.lib.stylix.colors.base0D}14)";
                color_inactive = lib.mkForce "rgba(${config.lib.stylix.colors.base00}0e)";
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

          # This 1×1 Top-layer surface appears only for global modal
          # widgets. The persistent Overlay-level modal host stays undimmed.
          layer_rule = [
            {
              match.namespace = "^linux-desktop-modal-dim$";
              dim_around = true;
            }
          ];

          # Inset the special workspace while preserving its existing
          # tiling and window-toggle workflow, including moved windows.
          workspace_rule = map (workspace: {
            inherit workspace;
            gaps_in = 12;
            gaps_out = {
              top = 180;
              right = 430;
              bottom = 180;
              left = 430;
            };
          }) ([ "special:magic" ] ++ map (number: "special:local-${toString number}") (lib.range 1 10));

          window_rule = [
            {
              # The theme prompt must coexist with the centre picker and the
              # desktop, even on the system-owned special workspace.
              match.class = "LinuxDesktopThemeSwitch";
              float = true;
              size = [
                640
                390
              ];
              move = [
                64
                90
              ];
            }
          ];

          on = {
            _args = [
              "hyprland.start"
              (lua ''
                function()
                  hl.exec_cmd("systemd-run --user --quiet --collect -- nm-applet --indicator")
                  hl.exec_cmd("systemd-run --user --quiet --collect -- dropbox")
                end
              '')
            ];
          };

          bind = map renderBinding globalKeybindings;
        };

        submaps = {
          launcher.settings.bind = map renderBinding launcherKeybindings;
          resize.settings.bind = map renderBinding resizeKeybindings;
          passthru.settings.bind = [
            (modBind "SHIFT + Escape" ''hl.dsp.submap("reset")'')
          ];
        };

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
