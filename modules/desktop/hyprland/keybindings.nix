let
  # Primary directional slots and their arrow alternatives for the
  # compositor and the shell.
  navigation = {
    left = [
      "H"
      "Left"
    ];
    down = [
      "J"
      "Down"
    ];
    up = [
      "K"
      "Up"
    ];
    right = [
      "L"
      "Right"
    ];
  };
in
{
  inherit navigation;

  bindings =
    {
      terminal,
      browser,
    }:
    let
      navigationKey = direction: builtins.head navigation.${direction};

      mk =
        {
          keys,
          action,
          section,
          description,
          id ? null,
          mainMod ? true,
          mehMod ? false,
          flags ? { },
          label ? null,
          cheatsheet ? true,
          submap ? null,
        }:
        {
          inherit
            action
            cheatsheet
            description
            flags
            id
            keys
            label
            mainMod
            mehMod
            section
            submap
            ;
        };

      mkMeh =
        args:
        mk (
          args
          // {
            mainMod = false;
            mehMod = true;
          }
        );

      exec = value: {
        type = "exec";
        inherit value;
      };

      # Launch graphical apps through the user manager, not the compositor's
      # environment (which remains stale across a NixOS theme switch).
      app = command: exec "systemd-run --user --quiet --collect -- ${command}";

      dispatcher = value: {
        type = "dispatcher";
        inherit value;
      };

      global = value: {
        type = "global";
        inherit value;
      };

      launcherResults = builtins.genList (
        index:
        mk {
          keys = toString (index + 1);
          action = global "desktop-shell:launcher-slot-${toString (index + 1)}";
          section = "LAUNCHERS";
          description = "Open launcher result ${toString (index + 1)}";
          cheatsheet = false;
          submap = "launcher";
        }
      ) 9;

      workspaceKeys =
        builtins.genList (
          index:
          let
            number = toString (index + 1);
          in
          {
            key = number;
            workspace = number;
          }
        ) 9
        ++ [
          {
            key = "0";
            workspace = "10";
          }
        ];

      focusWorkspace =
        entry:
        mk {
          keys = entry.key;
          action = dispatcher ''hl.dsp.focus({ workspace = "${entry.workspace}" })'';
          section = "WORKSPACES";
          description = "Workspace ${entry.workspace}";
        };

      moveToWorkspace =
        entry:
        mk {
          keys = "SHIFT + ${entry.key}";
          action = dispatcher ''hl.dsp.window.move({ workspace = "${entry.workspace}", follow = false })'';
          section = "WORKSPACES";
          description = "Move window to workspace ${entry.workspace}";
        };
    in
    [
      (mkMeh {
        keys = "J";
        id = "terminal.open";
        action = app terminal;
        section = "APPS";
        description = "Terminal";
      })
      (mkMeh {
        keys = "U";
        action = app "spotify";
        section = "APPS";
        description = "Spotify";
      })
      (mkMeh {
        keys = "K";
        action = app browser;
        section = "APPS";
        description = "Browser";
      })
      (mkMeh {
        keys = "M";
        action = app "floorp";
        section = "APPS";
        description = "Floorp";
      })
      (mkMeh {
        keys = "I";
        action = app "thunderbird";
        section = "APPS";
        description = "Thunderbird";
      })
      (mkMeh {
        keys = "L";
        action = app "code";
        section = "APPS";
        description = "Visual Studio Code";
      })
      (mkMeh {
        keys = "O";
        action = app "obsidian --disable-gpu";
        section = "APPS";
        description = "Obsidian";
      })
      (mkMeh {
        keys = "N";
        action = app "nautilus";
        section = "APPS";
        description = "Files";
      })
      (mk {
        keys = "M";
        id = "audio.mixer";
        action = global "desktop-shell:audio-mixer";
        section = "AUDIO & MEDIA";
        description = "Application mixer";
      })
      (mkMeh {
        keys = "P";
        action = exec "[float] systemd-run --user --quiet --collect -- easyeffects";
        section = "AUDIO & MEDIA";
        description = "Audio effects";
      })

      (mk {
        keys = "SUPER + SPACE";
        mainMod = false;
        id = "launcher.toggle";
        action = global "desktop-shell:launcher";
        section = "LAUNCHERS";
        description = "App & command launcher";
      })
      (mk {
        keys = "W";
        id = "wallpaper.toggle";
        action = global "desktop-shell:wallpaper";
        section = "SYSTEM";
        description = "Wallpaper gallery";
      })
      (mk {
        keys = "ALT + P";
        id = "capture.history";
        action = global "desktop-shell:captures";
        section = "UTILITIES";
        description = "Capture history";
      })
      (mk {
        keys = "C";
        id = "clipboard.toggle";
        action = global "desktop-shell:clipboard";
        section = "LAUNCHERS";
        description = "Clipboard history";
      })
      (mk {
        keys = "SUPER + TAB";
        mainMod = false;
        id = "overview.toggle";
        action = global "desktop-shell:overview";
        section = "WORKSPACES";
        description = "Workspaces & window overview";
      })
      (mk {
        keys = "SHIFT + P";
        id = "capture.recordToggle";
        action = global "desktop-shell:record-toggle";
        section = "UTILITIES";
        description = "Screen record";
      })
      (mk {
        keys = "P";
        id = "capture.region";
        action = global "desktop-shell:capture-region";
        section = "UTILITIES";
        description = "Screenshot";
      })
      (mk {
        keys = "SUPER + SPACE";
        mainMod = false;
        action = global "desktop-shell:launcher";
        section = "LAUNCHERS";
        description = "Close app & command launcher";
        cheatsheet = false;
        submap = "launcher";
      })

      (mk {
        keys = "Q";
        action = dispatcher "hl.dsp.window.close()";
        section = "WINDOWS";
        description = "Close window";
      })
      (mk {
        keys = "SHIFT + F";
        action = dispatcher "hl.dsp.window.float()";
        section = "WINDOWS";
        description = "Toggle floating";
      })
      (mk {
        keys = "ALT + F";
        action = dispatcher "hl.dsp.window.pin()";
        section = "WINDOWS";
        description = "Pin window";
      })
      (mk {
        keys = "G";
        action = dispatcher "hl.dsp.window.pseudo()";
        section = "WINDOWS";
        description = "Toggle pseudo tiling";
      })
      (mk {
        keys = "T";
        action = dispatcher ''hl.dsp.layout("togglesplit")'';
        section = "WINDOWS";
        description = "Toggle split direction";
      })
      (mk {
        keys = "F";
        action = dispatcher ''hl.dsp.window.fullscreen({ mode = "maximized" })'';
        section = "WINDOWS";
        description = "Toggle fullscreen";
      })
      (mk {
        keys = "mouse:272";
        action = dispatcher "hl.dsp.window.drag()";
        flags.mouse = true;
        section = "WINDOWS";
        description = "Drag window";
        label = "LMB";
      })
      (mk {
        keys = "mouse:273";
        action = dispatcher "hl.dsp.window.resize()";
        flags.mouse = true;
        section = "WINDOWS";
        description = "Resize window";
        label = "RMB";
      })

      (mk {
        keys = navigationKey "left";
        action = dispatcher ''hl.dsp.focus({ direction = "left" })'';
        section = "WINDOWS";
        description = "Focus left";
      })
      (mk {
        keys = navigationKey "down";
        action = dispatcher ''hl.dsp.focus({ direction = "down" })'';
        section = "WINDOWS";
        description = "Focus down";
      })
      (mk {
        keys = navigationKey "up";
        action = dispatcher ''hl.dsp.focus({ direction = "up" })'';
        section = "WINDOWS";
        description = "Focus up";
      })
      (mk {
        keys = navigationKey "right";
        action = dispatcher ''hl.dsp.focus({ direction = "right" })'';
        section = "WINDOWS";
        description = "Focus right";
      })

      (mk {
        keys = "SHIFT + ${navigationKey "left"}";
        action = dispatcher ''hl.dsp.window.move({ direction = "left" })'';
        section = "WINDOWS";
        description = "Move window left";
      })
      (mk {
        keys = "SHIFT + ${navigationKey "down"}";
        action = dispatcher ''hl.dsp.window.move({ direction = "down" })'';
        section = "WINDOWS";
        description = "Move window down";
      })
      (mk {
        keys = "SHIFT + ${navigationKey "up"}";
        action = dispatcher ''hl.dsp.window.move({ direction = "up" })'';
        section = "WINDOWS";
        description = "Move window up";
      })
      (mk {
        keys = "SHIFT + ${navigationKey "right"}";
        action = dispatcher ''hl.dsp.window.move({ direction = "right" })'';
        section = "WINDOWS";
        description = "Move window right";
      })

      (mk {
        keys = "ALT + ${navigationKey "left"}";
        action = dispatcher "hl.dsp.window.resize({ x = -50, y = 0, relative = true })";
        section = "WINDOWS";
        description = "Shrink window width";
      })
      (mk {
        keys = "ALT + ${navigationKey "down"}";
        action = dispatcher "hl.dsp.window.resize({ x = 0, y = 50, relative = true })";
        section = "WINDOWS";
        description = "Grow window height";
      })
      (mk {
        keys = "ALT + ${navigationKey "up"}";
        action = dispatcher "hl.dsp.window.resize({ x = 0, y = -50, relative = true })";
        section = "WINDOWS";
        description = "Shrink window height";
      })
      (mk {
        keys = "ALT + ${navigationKey "right"}";
        action = dispatcher "hl.dsp.window.resize({ x = 50, y = 0, relative = true })";
        section = "WINDOWS";
        description = "Grow window width";
      })
      (mk {
        keys = "R";
        id = "window.resizeMode";
        action = global "desktop-shell:resize-mode";
        section = "WINDOWS";
        description = "Resize window with a visual keyboard mode";
      })
    ]
    ++ launcherResults
    ++ map focusWorkspace workspaceKeys
    ++ map moveToWorkspace workspaceKeys
    ++ [
      (mk {
        keys = "SHIFT + V";
        action = dispatcher ''hl.dsp.window.move({ monitor = "+1", follow = false })'';
        section = "DISPLAY";
        description = "Move window to next display";
      })
      (mk {
        keys = "V";
        action = dispatcher ''hl.dsp.focus({ monitor = "+1" })'';
        section = "DISPLAY";
        description = "Focus next display";
      })
      (mk {
        keys = "ALT + V";
        action = dispatcher ''hl.dsp.focus({ monitor = "-1" })'';
        section = "DISPLAY";
        description = "Focus previous display";
      })
      (mk {
        keys = "SHIFT + I";
        action = dispatcher ''hl.dsp.window.move({ workspace = "e-1", follow = false })'';
        section = "WORKSPACES";
        description = "Move window to previous workspace";
      })
      (mk {
        keys = "SHIFT + O";
        action = dispatcher ''hl.dsp.window.move({ workspace = "e+1", follow = false })'';
        section = "WORKSPACES";
        description = "Move window to next workspace";
      })
      (mk {
        keys = "I";
        id = "workspace.previous";
        action = dispatcher ''hl.dsp.focus({ workspace = "e-1" })'';
        section = "WORKSPACES";
        description = "Previous workspace";
      })
      (mk {
        keys = "O";
        id = "workspace.next";
        action = dispatcher ''hl.dsp.focus({ workspace = "e+1" })'';
        section = "WORKSPACES";
        description = "Next workspace";
      })
      (mk {
        keys = "E";
        action = exec "desktop-shell-local-scratchpad move";
        section = "WORKSPACES";
        description = "Park or restore window in this workspace's scratchpad";
      })
      (mk {
        keys = "SHIFT + E";
        action = exec "desktop-shell-local-scratchpad toggle";
        section = "WORKSPACES";
        description = "Open or leave this workspace's scratchpad";
      })
      (mk {
        keys = "X";
        action = dispatcher ''hl.dsp.workspace.toggle_special("magic")'';
        section = "WORKSPACES";
        description = "Toggle special workspace";
      })
      (mk {
        keys = "SHIFT + X";
        action = dispatcher ''hl.dsp.window.move({ workspace = "special:magic", follow = false })'';
        section = "WORKSPACES";
        description = "Send window to special workspace";
      })
      (mk {
        keys = "mouse_down";
        action = dispatcher ''hl.dsp.focus({ workspace = "e+1" })'';
        section = "WORKSPACES";
        description = "Next workspace";
        label = "WHEEL ↓";
      })
      (mk {
        keys = "mouse_up";
        action = dispatcher ''hl.dsp.focus({ workspace = "e-1" })'';
        section = "WORKSPACES";
        description = "Previous workspace";
        label = "WHEEL ↑";
      })

      (mk {
        keys = "SHIFT + Z";
        id = "status.inspect";
        action = global "desktop-shell:status-peek";
        section = "SYSTEM";
        description = "Inspect current system and input state";
      })
      (mk {
        keys = "Caps_Lock";
        mainMod = false;
        id = "keyboard.capsLock";
        action = global "desktop-shell:keyboard-caps-lock";
        flags.non_consuming = true;
        section = "KEYBOARD";
        description = "Report compositor Caps Lock state";
        cheatsheet = false;
      })
      (mk {
        keys = "Num_Lock";
        mainMod = false;
        id = "keyboard.numLock";
        action = global "desktop-shell:keyboard-num-lock";
        flags.non_consuming = true;
        section = "KEYBOARD";
        description = "Report compositor Num Lock state";
        cheatsheet = false;
      })
      (mk {
        keys = "ALT + M";
        id = "audio.microphoneMute";
        action = global "desktop-shell:microphone-mute";
        section = "AUDIO & MEDIA";
        description = "Toggle default microphone mute";
      })
      (mk {
        keys = "XF86AudioMicMute";
        mainMod = false;
        id = "audio.microphoneMuteHardware";
        action = global "desktop-shell:microphone-mute";
        section = "AUDIO & MEDIA";
        description = "Toggle default microphone mute from hardware key";
        cheatsheet = false;
      })
      (mk {
        keys = "XF86AudioRaiseVolume";
        mainMod = false;
        id = "audio.volumeUp";
        action = global "desktop-shell:volume-up";
        flags.repeating = true;
        section = "AUDIO & MEDIA";
        description = "Volume up";
        label = "VOLUME +";
      })
      (mk {
        keys = "XF86AudioLowerVolume";
        mainMod = false;
        id = "audio.volumeDown";
        action = global "desktop-shell:volume-down";
        flags.repeating = true;
        section = "AUDIO & MEDIA";
        description = "Volume down";
        label = "VOLUME −";
      })
      (mk {
        keys = "XF86AudioMute";
        mainMod = false;
        id = "audio.toggleMute";
        action = global "desktop-shell:volume-mute";
        section = "AUDIO & MEDIA";
        description = "Mute";
        label = "MUTE";
      })
      (mk {
        keys = "N";
        id = "media.toggle";
        action = global "desktop-shell:media";
        section = "AUDIO & MEDIA";
        description = "Now playing";
      })
      (mk {
        keys = "bracketleft";
        id = "media.seekBackward";
        action = global "desktop-shell:media-seek-backward";
        flags.repeating = true;
        section = "AUDIO & MEDIA";
        description = "Seek backward by configured interval";
        label = "[";
      })
      (mk {
        keys = "bracketright";
        id = "media.seekForward";
        action = global "desktop-shell:media-seek-forward";
        flags.repeating = true;
        section = "AUDIO & MEDIA";
        description = "Seek forward by configured interval";
        label = "]";
      })
      (mk {
        keys = "XF86AudioPlay";
        mainMod = false;
        id = "media.playPause";
        action = global "desktop-shell:media-play-pause";
        section = "AUDIO & MEDIA";
        description = "Play / pause";
        cheatsheet = false;
      })
      (mk {
        keys = "XF86AudioNext";
        mainMod = false;
        id = "media.next";
        action = global "desktop-shell:media-next";
        section = "AUDIO & MEDIA";
        description = "Next track";
        cheatsheet = false;
      })
      (mk {
        keys = "XF86AudioPrev";
        mainMod = false;
        id = "media.previous";
        action = global "desktop-shell:media-previous";
        section = "AUDIO & MEDIA";
        description = "Previous track";
        cheatsheet = false;
      })

      (mk {
        keys = "XF86MonBrightnessUp";
        mainMod = false;
        id = "brightness.up";
        action = global "desktop-shell:brightness-up";
        flags.repeating = true;
        section = "DISPLAY";
        description = "Brightness up";
        label = "BRIGHTNESS +";
      })
      (mk {
        keys = "XF86MonBrightnessDown";
        mainMod = false;
        id = "brightness.down";
        action = global "desktop-shell:brightness-down";
        flags.repeating = true;
        section = "DISPLAY";
        description = "Brightness down";
        label = "BRIGHTNESS −";
      })
      (mk {
        keys = "D";
        id = "notifications.toggle";
        action = global "desktop-shell:notifications";
        section = "SYSTEM";
        description = "Open Activity tab";
      })
      (mk {
        keys = "SHIFT + D";
        id = "notifications.act";
        action = global "desktop-shell:notifications-act";
        section = "SYSTEM";
        description = "Activate latest notification, or open Activity";
      })
      (mk {
        keys = "CTRL + D";
        id = "notifications.dismissLatest";
        action = global "desktop-shell:notifications-dismiss";
        section = "SYSTEM";
        description = "Dismiss latest visible notification";
      })
      (mk {
        keys = "SHIFT + C";
        id = "session.lock";
        action = global "desktop-shell:lock";
        section = "SYSTEM";
        description = "Lock";
      })
      (mk {
        keys = "CTRL + ALT + DELETE";
        mainMod = false;
        id = "session.toggle";
        action = global "desktop-shell:session";
        section = "SYSTEM";
        description = "Session menu";
        label = "CTRL + ALT + DELETE";
      })
      (mkMeh {
        keys = "H";
        action = app "edit-config";
        section = "SYSTEM";
        description = "Edit desktop configuration";
      })
      (mk {
        keys = "A";
        id = "home.toggle";
        action = global "desktop-shell:home";
        section = "SYSTEM";
        description = "Open Home tab";
      })
      (mk {
        keys = "S";
        id = "controls.toggle";
        action = global "desktop-shell:controls";
        section = "SYSTEM";
        description = "Open Controls tab";
      })
      (mk {
        keys = "Y";
        id = "theme.toggle";
        action = global "desktop-shell:theme";
        section = "SYSTEM";
        description = "Theme picker";
      })
      (mk {
        keys = "SHIFT + Y";
        id = "colour.pick";
        action = global "desktop-shell:colour-pick";
        section = "UTILITIES";
        description = "Pick colour to clipboard";
      })
      (mk {
        keys = "SHIFT + M";
        id = "animations.toggle";
        action = global "desktop-shell:animations";
        section = "SYSTEM";
        description = "Toggle animations";
      })
      (mk {
        keys = "SHIFT + W";
        id = "media.wallpaperSpectrum";
        action = global "desktop-shell:wallpaper-spectrum";
        section = "AUDIO & MEDIA";
        description = "Toggle wallpaper spectrum";
      })
      (mk {
        keys = "SHIFT + N";
        id = "media.reactiveShell";
        action = global "desktop-shell:music-reactive";
        section = "AUDIO & MEDIA";
        description = "Toggle music-reactive shell";
      })
      (mk {
        keys = "ALT + Y";
        id = "window.effects.toggle";
        action = global "desktop-shell:window-effects";
        section = "WINDOWS";
        description = "Toggle window transparency";
      })
      (mk {
        keys = "SHIFT + B";
        id = "bar.toggle";
        action = global "desktop-shell:bar";
        section = "SYSTEM";
        description = "Toggle top bar";
      })
      (mk {
        keys = "slash";
        id = "shortcuts.toggle";
        action = global "desktop-shell:cheatsheet";
        section = "SYSTEM";
        description = "Show keyboard shortcuts";
        label = "/";
      })
      (mk {
        keys = "Escape";
        id = "keyboard.passthruEnter";
        action = dispatcher ''hl.dsp.submap("passthru")'';
        section = "SYSTEM";
        description = "Enter passthrough mode";
      })
      (mk {
        keys = "SHIFT + Escape";
        submap = "passthru";
        id = "keyboard.passthruExit";
        action = dispatcher ''hl.dsp.submap("reset")'';
        section = "SYSTEM";
        description = "Exit passthrough mode";
        cheatsheet = false;
      })
    ];
}
