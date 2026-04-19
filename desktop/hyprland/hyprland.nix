{ config, pkgs, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    extraConfig = ''
      #
      # Me first try at setting up Hyprland (yayyy)
      #
      # Please note not all available settings / options are set here.
      # For a full list, see the wiki
      #
      #
      # See https://wiki.hyprland.org/Configuring/Monitors/
      # monitor=,preferred,auto,auto
      # monitor = HDMI-A-1, 3840x2160@60, 0x0, 1.5
      # monitor = eDP-1, 1920x1080@60, 0x0, 1.0

      # Using nwg-display to configure monitors
      source = ~/.config/hypr/monitors.conf

      # Unscale xwayland
      xwayland {
          force_zero_scaling = true
      }

      # See https://wiki.hyprland.org/Configuring/Keywords/ for more

      # Execute your favorite apps at launch
      # exec-once = waybar & hyprpaper & firefox

      # Wallpaper daemon
      exec-once = awww init && awww img ~/.config/home-manager/wallpaper.png

      # Status bar
      exec-once = waybar
      # Applets
      # NetworkManager
      exec-once = nm-applet --indicator

      # Notification daemon
      exec-once = dunst

      # OSD
      exec-once = avizo-service

      # Clipboard daemon
      exec-once = wl-paste --type text --watch cliphist store #Stores only text data

      exec-once = wl-paste --type image --watch cliphist store #Stores only image data

      # Playerctld: to track media players
      exec-once = playerctld daemon

      # Dropbox
      exec-once = dropbox

      # Polkit
      exec-once = ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1

      # Source a file (multi-file configs)
      # source = ~/.config/hypr/myColors.conf

      # Some default env vars.
      # env = XCURSOR_SIZE,30

      # Telling Hyprland which GPU to use
      # env = WLR_DRM_DEVICES,/dev/dri/card0:/dev/dri/card1

      # Run on Nvidia GPU
      # env = WLR_DRM_DEVICES,/dev/dri/card1

      # Run on Intel GPU
      # env = WLR_DRM_DEVICES,/dev/dri/card0

      # For all categories, see https://wiki.hyprland.org/Configuring/Variables/
      input {
          kb_layout = us
          kb_variant =
          kb_model =
          kb_options =
          kb_rules =

          # key repeat rate
          repeat_rate = 35

          # key repeat delay
          repeat_delay = 225

          follow_mouse = 1

          accel_profile = flat

          touchpad {
              natural_scroll = true
              scroll_factor = 0.2
              tap-to-click = true
              tap-and-drag = true
          }

          sensitivity = 0.5 # -1.0 - 1.0, 0 means no modification.
      }

      general {
          # See https://wiki.hyprland.org/Configuring/Variables/ for more

          gaps_in = 5
          gaps_out = 15
          border_size = 0
          layout = dwindle

          # Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on
          allow_tearing = false
      }

      decoration {
          # See https://wiki.hyprland.org/Configuring/Variables/ for more

          rounding = 10

          blur {
              enabled = true
              size = 3
              passes = 1
          }

          # add drop shadows behind windows for depth effect
          shadow {
            enabled = true
            range = 30
            render_power = 3
          }
      }

      animations {
          enabled = yes

          # Some default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more

          bezier = myBezier, 0.05, 0.9, 0.1, 1.05

          animation = windows, 1, 4, myBezier
          animation = windowsOut, 1, 4, default, popin 80%
          animation = border, 1, 4, default
          animation = borderangle, 1, 4, default
          animation = fade, 1, 4, default
          animation = workspaces, 1, 4, default
          animation = specialWorkspace, 1, 4, default, slidefadevert 20%
      }

      dwindle {
          # See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
          pseudotile = yes # master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
          preserve_split = yes # you probably want this
      }

      master {
          # See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
          new_status = slave
      }

      # gesture: 3 finger swipe horizontal to move workspaces horizontally
      gesture = 3, horizontal, workspace

      misc {
          # See https://wiki.hyprland.org/Configuring/Variables/ for more
          force_default_wallpaper = 0 # Set to 0 to disable the anime mascot wallpapers
          disable_hyprland_logo = true # Set to true to disable the hyprland logo on the lockscreen
          disable_splash_rendering = true # Set to true to disable the splash screen rendering
          enable_swallow =  true
          swallow_regex = ^(kitty)$

          # Allow apps to focus when requested to (E.G. by a notification or signing in via the browser)
          focus_on_activate = true
      }

      # Example per-device config
      # See https://wiki.hyprland.org/Configuring/Keywords/#executing for more
      device {
          name = epic-mouse-v1
          sensitivity = -0.5
      }

      # Example windowrule v1
      # windowrule = float, ^(kitty)$
      # Example windowrule v2
      # windowrulev2 = float,class:^(kitty)$,title:^(kitty)$
      # See https://wiki.hyprland.org/Configuring/Window-Rules/ for more
      #
      # Make Polkit (KDE) always be floating, centred and a fixed size
      # must add class: before program name
      windowrule = float on, match:class = polkit-kde-authentication-agent-1
      windowrule = center on, match:class = polkit-kde-authentication-agent-1
      windowrule = size 500 250, match:class = polkit-kde-authentication-agent-1


      # BINDINGS (Keyboard Shortcuts)
      # See https://wiki.hyprland.org/Configuring/Keywords/ for more
      $mainMod = SUPER
      # Extra info: https://wiki.hyprland.org/Configuring/Binds/


      # Favourite Apps
      bind = $mainMod ALT, 1, exec, kitty
      bind = $mainMod ALT, 2, exec, spotify
      bind = $mainMod ALT, 3, exec, brave
      bind = $mainMod ALT, 4, exec, floorp
      bind = $mainMod ALT, 5, exec, thunderbird
      bind = $mainMod ALT, 6, exec, code
      bind = $mainMod ALT, 7, exec, obsidian --disable-gpu
      bind = $mainMod ALT, E, exec, nautilus
      bind = $mainMod SHIFT, V, exec, ~/.files/scripts/volume_mixer
      bind = $mainMod ALT, V, exec, ~/.files/scripts/audio_fx

      # Applets and launchers
      bind = $mainMod, SPACE, exec, ~/.files/scripts/app_launch
      bind = $mainMod, V, exec, cliphist list | tofi | cliphist decode | wl-copy
      bind = ALT, SPACE, exec, ~/repos/rofi-desktop/scripts/rofi-desktop.sh

      # Window management
      bind = $mainMod, Q, killactive,
      bind = $mainMod, M, exit,
      bind = $mainMod_SHIFT, F, togglefloating,
      bind = $mainMod SHIFT, P, pin
      bind = $mainMod, P, pseudo, # dwindle
      bind = $mainMod, J, togglesplit, # dwindle
      # Fullscreen
      bind = $mainMod,f,fullscreen,1

      # Move/resize windows with mainMod + LMB/RMB and dragging
      bindm = $mainMod, mouse:272, movewindow
      bindm = $mainMod, mouse:273, resizewindow

      # Move focus with mainMod + WASD
      bind = $mainMod, A, movefocus, l
      bind = $mainMod, D, movefocus, r
      bind = $mainMod, W, movefocus, u
      bind = $mainMod, S, movefocus, d

      # Workspace management
      # Switch workspaces with mainMod + [0-9]
      bind = $mainMod, 1, workspace, 1
      bind = $mainMod, 2, workspace, 2
      bind = $mainMod, 3, workspace, 3
      bind = $mainMod, 4, workspace, 4
      bind = $mainMod, 5, workspace, 5
      bind = $mainMod, 6, workspace, 6
      bind = $mainMod, 8, workspace, 8
      bind = $mainMod, 7, workspace, 7
      bind = $mainMod, 9, workspace, 9
      bind = $mainMod, 0, workspace, 10

      # Move active window to a workspace with mainMod + SHIFT + [0-9]
      bind = $mainMod SHIFT, 1, movetoworkspacesilent, 1
      bind = $mainMod SHIFT, 2, movetoworkspacesilent, 2
      bind = $mainMod SHIFT, 3, movetoworkspacesilent, 3
      bind = $mainMod SHIFT, 4, movetoworkspacesilent, 4
      bind = $mainMod SHIFT, 5, movetoworkspacesilent, 5
      bind = $mainMod SHIFT, 6, movetoworkspacesilent, 6
      bind = $mainMod SHIFT, 7, movetoworkspacesilent, 7
      bind = $mainMod SHIFT, 8, movetoworkspacesilent, 8
      bind = $mainMod SHIFT, 9, movetoworkspacesilent, 9
      bind = $mainMod SHIFT, 0, movetoworkspacesilent, 10

      # Resize active window with arrow keys
      binde = $mainMod SHIFT, D, resizeactive, 50 0
      binde = $mainMod SHIFT, A, resizeactive, -50 0
      binde = $mainMod SHIFT, W, resizeactive, 0 -50
      binde = $mainMod SHIFT, S, resizeactive, 0 50

      # Example special workspace (scratchpad)
      bind = $mainMod, X, togglespecialworkspace, magic
      bind = $mainMod SHIFT, X, movetoworkspace, special:magic

      # Movement between workspaces
      # Scroll through existing workspaces with mainMod + scroll
      bind = $mainMod, mouse_down, workspace, e+1
      bind = $mainMod, mouse_up, workspace, e-1
      # Change workspace with arrow keys
      bind = $mainMod CTRL, A, workspace, e-1
      bind = $mainMod CTRL, D, workspace, e+1


      # Media Keys
      binde=, XF86AudioRaiseVolume, exec, volumectl + 5
      binde=, XF86AudioLowerVolume, exec, volumectl - 5
      bind=, XF86AudioMute, exec, volumectl %

      # Play/Pause
      bind = $mainMod ALT, X, exec, playerctl play-pause

      # Skip
      # Forward
      bind = $mainMod ALT, C, exec, playerctl next
      # Previous
      bind = $mainMod ALT, Z, exec, playerctl previous

      # Seek
      # Forward
      binde = $mainMod ALT, D, exec, playerctl position 10+
      # Backwards
      binde = $mainMod ALT, S, exec, playerctl position 10-

      # Shuffle
      bind = $mainMod ALT, W, exec, playerctl shuffle toggle

      # Switch source
      bind = $mainMod ALT, F, exec, playerctld shift

      # Monitor Brightness
      binde=, XF86MonBrightnessUp, exec, lightctl + 5
      binde=, XF86MonBrightnessDown, exec, lightctl - 5

      # Lock screen (swaylock)
      bind = $mainMod, L, exec, swaylock

      # Edit config in vscode
      bind = $mainMod SHIFT, E, exec, code /home/joshan/.files/edit_config.code-workspace

      # Passthrough Super key to a VM
      bind = $mainMod, Escape, submap, passthru
      submap = passthru
      bind = $mainMod SHIFT, Escape, submap, reset
      submap = reset

    '';
  };
}
