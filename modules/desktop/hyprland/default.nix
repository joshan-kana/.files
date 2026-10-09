{
  config,
  lib,
  pkgs,
  ...
}:

let
  xwaylandEnabled = true;
  terminal = config.dotfiles.defaults.terminal;
  windowEffectsToggle = pkgs.writeShellApplication {
    name = "linux-desktop-window-effects-toggle";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      current="$(hyprctl getoption decoration:active_opacity -j | jq -er '.float')"
      if jq -ne --argjson current "$current" '$current < 0.999' >/dev/null; then
        opacity=1.0
      else
        opacity=0.82
      fi
      hyprctl eval "hl.config({ decoration = { active_opacity = $opacity, inactive_opacity = $opacity } })"
    '';
  };
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

  systemd.user.services = {
    xdg-desktop-portal-hyprland = {
      overrideStrategy = "asDropin";
      serviceConfig.RestartSec = 3;
    };
    xdg-desktop-portal-gtk = {
      overrideStrategy = "asDropin";
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 3;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    wl-clipboard
    brightnessctl
    polkit_gnome
    networkmanagerapplet
    grimblast
    nwg-panel
    nwg-dock-hyprland
    nwg-displays
    wlr-randr
  ];

  shell = import ./shell;

  lock = _: {
    security.pam.services.linux-desktop = { };
  };

  cliphist = _: {
    home = _: {
      services.cliphist = { };
    };
  };

  home = _: {
    # disable hyprpaper target to prevent crash loops
    stylix.targets.hyprland.hyprpaper.enable = false;

    home.shellAliases = aliases;
    home.packages = [ windowEffectsToggle ];

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
                size = 8;
                passes = 2;
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
                  hl.exec_cmd("nm-applet --indicator")
                  hl.exec_cmd("dropbox")
                  hl.exec_cmd("${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1")
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
