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

      # Entries are plain records; only optional fields need defaults.
      defaults = {
        mods = [ "main" ];
        id = null;
        flags = { };
        label = null;
        cheatsheet = true;
        submap = null;
      };

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

      launcherResults = builtins.genList (index: {
        key = toString (index + 1);
        action = global "desktop-shell:launcher-slot-${toString (index + 1)}";
        section = "LAUNCHERS";
        description = "Open launcher result ${toString (index + 1)}";
        cheatsheet = false;
        submap = "launcher";
      }) 9;

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

      focusWorkspace = entry: {
        inherit (entry) key;
        action = dispatcher ''hl.dsp.focus({ workspace = "${entry.workspace}" })'';
        section = "WORKSPACES";
        description = "Workspace ${entry.workspace}";
      };

      moveToWorkspace = entry: {
        inherit (entry) key;
        mods = [
          "main"
          "shift"
        ];
        action = dispatcher ''hl.dsp.window.move({ workspace = "${entry.workspace}", follow = false })'';
        section = "WORKSPACES";
        description = "Move window to workspace ${entry.workspace}";
      };
    in
    map (entry: defaults // entry) (
      [
        {
          key = "J";
          mods = [ "meh" ];
          id = "terminal.open";
          action = app terminal;
          section = "APPS";
          description = "Terminal";
        }
        {
          key = "U";
          mods = [ "meh" ];
          action = app "spotify";
          section = "APPS";
          description = "Spotify";
        }
        {
          key = "K";
          mods = [ "meh" ];
          action = app browser;
          section = "APPS";
          description = "Browser";
        }
        {
          key = "M";
          mods = [ "meh" ];
          action = app "floorp";
          section = "APPS";
          description = "Floorp";
        }
        {
          key = "I";
          mods = [ "meh" ];
          action = app "thunderbird";
          section = "APPS";
          description = "Thunderbird";
        }
        {
          key = "L";
          mods = [ "meh" ];
          action = app "code";
          section = "APPS";
          description = "Visual Studio Code";
        }
        {
          key = "O";
          mods = [ "meh" ];
          action = app "obsidian --disable-gpu";
          section = "APPS";
          description = "Obsidian";
        }
        {
          key = "N";
          mods = [ "meh" ];
          action = app "nautilus";
          section = "APPS";
          description = "Files";
        }
        {
          key = "M";
          id = "audio.mixer";
          action = global "desktop-shell:audio-mixer";
          section = "AUDIO & MEDIA";
          description = "Application mixer";
        }
        {
          key = "P";
          mods = [ "meh" ];
          action = exec "[float] systemd-run --user --quiet --collect -- easyeffects";
          section = "AUDIO & MEDIA";
          description = "Audio effects";
        }

        {
          key = "SPACE";
          mods = [ "super" ];
          id = "launcher.toggle";
          action = global "desktop-shell:launcher";
          section = "LAUNCHERS";
          description = "App & command launcher";
        }
        {
          key = "W";
          id = "wallpaper.toggle";
          action = global "desktop-shell:wallpaper";
          section = "SYSTEM";
          description = "Wallpaper gallery";
        }
        {
          key = "P";
          mods = [
            "main"
            "alt"
          ];
          id = "capture.history";
          action = global "desktop-shell:captures";
          section = "UTILITIES";
          description = "Capture history";
        }
        {
          key = "C";
          id = "clipboard.toggle";
          action = global "desktop-shell:clipboard";
          section = "LAUNCHERS";
          description = "Clipboard history";
        }
        {
          key = "TAB";
          mods = [ "super" ];
          id = "overview.toggle";
          action = global "desktop-shell:overview";
          section = "WORKSPACES";
          description = "Workspaces & window overview";
        }
        {
          key = "P";
          mods = [
            "main"
            "shift"
          ];
          id = "capture.recordToggle";
          action = global "desktop-shell:record-toggle";
          section = "UTILITIES";
          description = "Screen record";
        }
        {
          key = "P";
          id = "capture.region";
          action = global "desktop-shell:capture-region";
          section = "UTILITIES";
          description = "Screenshot";
        }
        {
          key = "SPACE";
          mods = [ "super" ];
          action = global "desktop-shell:launcher";
          section = "LAUNCHERS";
          description = "Close app & command launcher";
          cheatsheet = false;
          submap = "launcher";
        }

        {
          key = "Q";
          action = dispatcher "hl.dsp.window.close()";
          section = "WINDOWS";
          description = "Close window";
        }
        {
          key = "F";
          mods = [
            "main"
            "shift"
          ];
          action = dispatcher "hl.dsp.window.float()";
          section = "WINDOWS";
          description = "Toggle floating";
        }
        {
          key = "F";
          mods = [
            "main"
            "alt"
          ];
          action = dispatcher "hl.dsp.window.pin()";
          section = "WINDOWS";
          description = "Pin window";
        }
        {
          key = "G";
          action = dispatcher "hl.dsp.window.pseudo()";
          section = "WINDOWS";
          description = "Toggle pseudo tiling";
        }
        {
          key = "T";
          action = dispatcher ''hl.dsp.layout("togglesplit")'';
          section = "WINDOWS";
          description = "Toggle split direction";
        }
        {
          key = "F";
          action = dispatcher ''hl.dsp.window.fullscreen({ mode = "maximized" })'';
          section = "WINDOWS";
          description = "Toggle fullscreen";
        }
        {
          key = "mouse:272";
          action = dispatcher "hl.dsp.window.drag()";
          flags.mouse = true;
          section = "WINDOWS";
          description = "Drag window";
          label = "LMB";
        }
        {
          key = "mouse:273";
          action = dispatcher "hl.dsp.window.resize()";
          flags.mouse = true;
          section = "WINDOWS";
          description = "Resize window";
          label = "RMB";
        }

        {
          key = navigationKey "left";
          action = dispatcher ''hl.dsp.focus({ direction = "left" })'';
          section = "WINDOWS";
          description = "Focus left";
        }
        {
          key = navigationKey "down";
          action = dispatcher ''hl.dsp.focus({ direction = "down" })'';
          section = "WINDOWS";
          description = "Focus down";
        }
        {
          key = navigationKey "up";
          action = dispatcher ''hl.dsp.focus({ direction = "up" })'';
          section = "WINDOWS";
          description = "Focus up";
        }
        {
          key = navigationKey "right";
          action = dispatcher ''hl.dsp.focus({ direction = "right" })'';
          section = "WINDOWS";
          description = "Focus right";
        }

        {
          key = navigationKey "left";
          mods = [
            "main"
            "shift"
          ];
          action = dispatcher ''hl.dsp.window.move({ direction = "left" })'';
          section = "WINDOWS";
          description = "Move window left";
        }
        {
          key = navigationKey "down";
          mods = [
            "main"
            "shift"
          ];
          action = dispatcher ''hl.dsp.window.move({ direction = "down" })'';
          section = "WINDOWS";
          description = "Move window down";
        }
        {
          key = navigationKey "up";
          mods = [
            "main"
            "shift"
          ];
          action = dispatcher ''hl.dsp.window.move({ direction = "up" })'';
          section = "WINDOWS";
          description = "Move window up";
        }
        {
          key = navigationKey "right";
          mods = [
            "main"
            "shift"
          ];
          action = dispatcher ''hl.dsp.window.move({ direction = "right" })'';
          section = "WINDOWS";
          description = "Move window right";
        }

        {
          key = navigationKey "left";
          mods = [
            "main"
            "alt"
          ];
          action = dispatcher "hl.dsp.window.resize({ x = -50, y = 0, relative = true })";
          section = "WINDOWS";
          description = "Shrink window width";
        }
        {
          key = navigationKey "down";
          mods = [
            "main"
            "alt"
          ];
          action = dispatcher "hl.dsp.window.resize({ x = 0, y = 50, relative = true })";
          section = "WINDOWS";
          description = "Grow window height";
        }
        {
          key = navigationKey "up";
          mods = [
            "main"
            "alt"
          ];
          action = dispatcher "hl.dsp.window.resize({ x = 0, y = -50, relative = true })";
          section = "WINDOWS";
          description = "Shrink window height";
        }
        {
          key = navigationKey "right";
          mods = [
            "main"
            "alt"
          ];
          action = dispatcher "hl.dsp.window.resize({ x = 50, y = 0, relative = true })";
          section = "WINDOWS";
          description = "Grow window width";
        }
        {
          key = "R";
          id = "window.resizeMode";
          action = global "desktop-shell:resize-mode";
          section = "WINDOWS";
          description = "Resize window with a visual keyboard mode";
        }
      ]
      ++ launcherResults
      ++ map focusWorkspace workspaceKeys
      ++ map moveToWorkspace workspaceKeys
      ++ [
        {
          key = "V";
          mods = [
            "main"
            "shift"
          ];
          action = dispatcher ''hl.dsp.window.move({ monitor = "+1", follow = false })'';
          section = "DISPLAY";
          description = "Move window to next display";
        }
        {
          key = "V";
          action = dispatcher ''hl.dsp.focus({ monitor = "+1" })'';
          section = "DISPLAY";
          description = "Focus next display";
        }
        {
          key = "V";
          mods = [
            "main"
            "alt"
          ];
          action = dispatcher ''hl.dsp.focus({ monitor = "-1" })'';
          section = "DISPLAY";
          description = "Focus previous display";
        }
        {
          key = "I";
          mods = [
            "main"
            "shift"
          ];
          action = dispatcher ''hl.dsp.window.move({ workspace = "e-1", follow = false })'';
          section = "WORKSPACES";
          description = "Move window to previous workspace";
        }
        {
          key = "O";
          mods = [
            "main"
            "shift"
          ];
          action = dispatcher ''hl.dsp.window.move({ workspace = "e+1", follow = false })'';
          section = "WORKSPACES";
          description = "Move window to next workspace";
        }
        {
          key = "I";
          id = "workspace.previous";
          action = dispatcher ''hl.dsp.focus({ workspace = "e-1" })'';
          section = "WORKSPACES";
          description = "Previous workspace";
        }
        {
          key = "O";
          id = "workspace.next";
          action = dispatcher ''hl.dsp.focus({ workspace = "e+1" })'';
          section = "WORKSPACES";
          description = "Next workspace";
        }
        {
          key = "E";
          action = exec "desktop-shell-local-scratchpad move";
          section = "WORKSPACES";
          description = "Park or restore window in this workspace's scratchpad";
        }
        {
          key = "E";
          mods = [
            "main"
            "shift"
          ];
          action = exec "desktop-shell-local-scratchpad toggle";
          section = "WORKSPACES";
          description = "Open or leave this workspace's scratchpad";
        }
        {
          key = "X";
          action = dispatcher ''hl.dsp.workspace.toggle_special("magic")'';
          section = "WORKSPACES";
          description = "Toggle special workspace";
        }
        {
          key = "X";
          mods = [
            "main"
            "shift"
          ];
          action = dispatcher ''hl.dsp.window.move({ workspace = "special:magic", follow = false })'';
          section = "WORKSPACES";
          description = "Send window to special workspace";
        }
        {
          key = "mouse_down";
          action = dispatcher ''hl.dsp.focus({ workspace = "e+1" })'';
          section = "WORKSPACES";
          description = "Next workspace";
          label = "WHEEL ↓";
        }
        {
          key = "mouse_up";
          action = dispatcher ''hl.dsp.focus({ workspace = "e-1" })'';
          section = "WORKSPACES";
          description = "Previous workspace";
          label = "WHEEL ↑";
        }

        {
          key = "Z";
          mods = [
            "main"
            "shift"
          ];
          id = "status.inspect";
          action = global "desktop-shell:status-peek";
          section = "SYSTEM";
          description = "Inspect current system and input state";
        }
        {
          key = "Caps_Lock";
          mods = [ ];
          id = "keyboard.capsLock";
          action = global "desktop-shell:keyboard-caps-lock";
          flags.non_consuming = true;
          section = "KEYBOARD";
          description = "Report compositor Caps Lock state";
          cheatsheet = false;
        }
        {
          key = "Num_Lock";
          mods = [ ];
          id = "keyboard.numLock";
          action = global "desktop-shell:keyboard-num-lock";
          flags.non_consuming = true;
          section = "KEYBOARD";
          description = "Report compositor Num Lock state";
          cheatsheet = false;
        }
        {
          key = "M";
          mods = [
            "main"
            "alt"
          ];
          id = "audio.microphoneMute";
          action = global "desktop-shell:microphone-mute";
          section = "AUDIO & MEDIA";
          description = "Toggle default microphone mute";
        }
        {
          key = "XF86AudioMicMute";
          mods = [ ];
          id = "audio.microphoneMuteHardware";
          action = global "desktop-shell:microphone-mute";
          section = "AUDIO & MEDIA";
          description = "Toggle default microphone mute from hardware key";
          cheatsheet = false;
        }
        {
          key = "XF86AudioRaiseVolume";
          mods = [ ];
          id = "audio.volumeUp";
          action = global "desktop-shell:volume-up";
          flags.repeating = true;
          section = "AUDIO & MEDIA";
          description = "Volume up";
          label = "VOLUME +";
        }
        {
          key = "XF86AudioLowerVolume";
          mods = [ ];
          id = "audio.volumeDown";
          action = global "desktop-shell:volume-down";
          flags.repeating = true;
          section = "AUDIO & MEDIA";
          description = "Volume down";
          label = "VOLUME −";
        }
        {
          key = "XF86AudioMute";
          mods = [ ];
          id = "audio.toggleMute";
          action = global "desktop-shell:volume-mute";
          section = "AUDIO & MEDIA";
          description = "Mute";
          label = "MUTE";
        }
        {
          key = "N";
          id = "media.toggle";
          action = global "desktop-shell:media";
          section = "AUDIO & MEDIA";
          description = "Now playing";
        }
        {
          key = "bracketleft";
          id = "media.seekBackward";
          action = global "desktop-shell:media-seek-backward";
          flags.repeating = true;
          section = "AUDIO & MEDIA";
          description = "Seek backward by configured interval";
          label = "[";
        }
        {
          key = "bracketright";
          id = "media.seekForward";
          action = global "desktop-shell:media-seek-forward";
          flags.repeating = true;
          section = "AUDIO & MEDIA";
          description = "Seek forward by configured interval";
          label = "]";
        }
        {
          key = "XF86AudioPlay";
          mods = [ ];
          id = "media.playPause";
          action = global "desktop-shell:media-play-pause";
          section = "AUDIO & MEDIA";
          description = "Play / pause";
          cheatsheet = false;
        }
        {
          key = "XF86AudioNext";
          mods = [ ];
          id = "media.next";
          action = global "desktop-shell:media-next";
          section = "AUDIO & MEDIA";
          description = "Next track";
          cheatsheet = false;
        }
        {
          key = "XF86AudioPrev";
          mods = [ ];
          id = "media.previous";
          action = global "desktop-shell:media-previous";
          section = "AUDIO & MEDIA";
          description = "Previous track";
          cheatsheet = false;
        }

        {
          key = "XF86MonBrightnessUp";
          mods = [ ];
          id = "brightness.up";
          action = global "desktop-shell:brightness-up";
          flags.repeating = true;
          section = "DISPLAY";
          description = "Brightness up";
          label = "BRIGHTNESS +";
        }
        {
          key = "XF86MonBrightnessDown";
          mods = [ ];
          id = "brightness.down";
          action = global "desktop-shell:brightness-down";
          flags.repeating = true;
          section = "DISPLAY";
          description = "Brightness down";
          label = "BRIGHTNESS −";
        }
        {
          key = "D";
          id = "notifications.toggle";
          action = global "desktop-shell:notifications";
          section = "SYSTEM";
          description = "Open Activity tab";
        }
        {
          key = "D";
          mods = [
            "main"
            "shift"
          ];
          id = "notifications.act";
          action = global "desktop-shell:notifications-act";
          section = "SYSTEM";
          description = "Activate latest notification, or open Activity";
        }
        {
          key = "D";
          mods = [
            "main"
            "ctrl"
          ];
          id = "notifications.dismissLatest";
          action = global "desktop-shell:notifications-dismiss";
          section = "SYSTEM";
          description = "Dismiss latest visible notification";
        }
        {
          key = "C";
          mods = [
            "main"
            "shift"
          ];
          id = "session.lock";
          action = global "desktop-shell:lock";
          section = "SYSTEM";
          description = "Lock";
        }
        {
          key = "DELETE";
          mods = [
            "ctrl"
            "alt"
          ];
          id = "session.toggle";
          action = global "desktop-shell:session";
          section = "SYSTEM";
          description = "Session menu";
        }
        {
          key = "H";
          mods = [ "meh" ];
          action = app "edit-config";
          section = "SYSTEM";
          description = "Edit desktop configuration";
        }
        {
          key = "A";
          id = "home.toggle";
          action = global "desktop-shell:home";
          section = "SYSTEM";
          description = "Open Home tab";
        }
        {
          key = "S";
          id = "controls.toggle";
          action = global "desktop-shell:controls";
          section = "SYSTEM";
          description = "Open Controls tab";
        }
        {
          key = "Y";
          id = "theme.toggle";
          action = global "desktop-shell:theme";
          section = "SYSTEM";
          description = "Theme picker";
        }
        {
          key = "Y";
          mods = [
            "main"
            "shift"
          ];
          id = "colour.pick";
          action = global "desktop-shell:colour-pick";
          section = "UTILITIES";
          description = "Pick colour to clipboard";
        }
        {
          key = "M";
          mods = [
            "main"
            "shift"
          ];
          id = "animations.toggle";
          action = global "desktop-shell:animations";
          section = "SYSTEM";
          description = "Toggle animations";
        }
        {
          key = "W";
          mods = [
            "main"
            "shift"
          ];
          id = "media.wallpaperSpectrum";
          action = global "desktop-shell:wallpaper-spectrum";
          section = "AUDIO & MEDIA";
          description = "Toggle wallpaper spectrum";
        }
        {
          key = "N";
          mods = [
            "main"
            "shift"
          ];
          id = "media.reactiveShell";
          action = global "desktop-shell:music-reactive";
          section = "AUDIO & MEDIA";
          description = "Toggle music-reactive shell";
        }
        {
          key = "Y";
          mods = [
            "main"
            "alt"
          ];
          id = "window.effects.toggle";
          action = global "desktop-shell:window-effects";
          section = "WINDOWS";
          description = "Toggle window transparency";
        }
        {
          key = "B";
          mods = [
            "main"
            "shift"
          ];
          id = "bar.toggle";
          action = global "desktop-shell:bar";
          section = "SYSTEM";
          description = "Toggle top bar";
        }
        {
          key = "slash";
          id = "shortcuts.toggle";
          action = global "desktop-shell:cheatsheet";
          section = "SYSTEM";
          description = "Show keyboard shortcuts";
          label = "/";
        }
        {
          key = "Escape";
          id = "keyboard.passthruEnter";
          action = dispatcher ''hl.dsp.submap("passthru")'';
          section = "SYSTEM";
          description = "Enter passthrough mode";
        }
        {
          key = "Escape";
          mods = [
            "main"
            "shift"
          ];
          submap = "passthru";
          id = "keyboard.passthruExit";
          action = dispatcher ''hl.dsp.submap("reset")'';
          section = "SYSTEM";
          description = "Exit passthrough mode";
          cheatsheet = false;
        }
      ]
    );
}
