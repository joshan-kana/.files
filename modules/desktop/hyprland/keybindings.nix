{
  terminal,
  browser,
}:

let
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
      action = global "linux-desktop:launcher-slot-${toString (index + 1)}";
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
    keys = "1";
    id = "terminal.open";
    action = app terminal;
    section = "APPS";
    description = "Terminal";
  })
  (mkMeh {
    keys = "2";
    action = app "spotify";
    section = "APPS";
    description = "Spotify";
  })
  (mkMeh {
    keys = "3";
    action = app browser;
    section = "APPS";
    description = "Browser";
  })
  (mkMeh {
    keys = "4";
    action = app "floorp";
    section = "APPS";
    description = "Floorp";
  })
  (mkMeh {
    keys = "5";
    action = app "thunderbird";
    section = "APPS";
    description = "Thunderbird";
  })
  (mkMeh {
    keys = "6";
    action = app "code";
    section = "APPS";
    description = "Visual Studio Code";
  })
  (mkMeh {
    keys = "7";
    action = app "obsidian --disable-gpu";
    section = "APPS";
    description = "Obsidian";
  })
  (mkMeh {
    keys = "E";
    action = app "nautilus";
    section = "APPS";
    description = "Files";
  })
  (mk {
    keys = "SHIFT + V";
    id = "audio.mixer";
    action = global "linux-desktop:audio-mixer";
    section = "AUDIO & MEDIA";
    description = "Application mixer";
  })
  (mkMeh {
    keys = "V";
    action = exec "[float] systemd-run --user --quiet --collect -- easyeffects";
    section = "AUDIO & MEDIA";
    description = "Audio effects";
  })

  (mk {
    keys = "SUPER + SPACE";
    mainMod = false;
    id = "launcher.toggle";
    action = global "linux-desktop:launcher";
    section = "LAUNCHERS";
    description = "App & command launcher";
  })
  (mk {
    keys = "C";
    id = "clipboard.toggle";
    action = global "linux-desktop:clipboard";
    section = "LAUNCHERS";
    description = "Clipboard history";
  })
  (mk {
    keys = "SUPER + TAB";
    mainMod = false;
    id = "overview.toggle";
    action = global "linux-desktop:overview";
    section = "WORKSPACES";
    description = "Workspaces & window overview";
  })
  (mk {
    keys = "SUPER + SHIFT + R";
    mainMod = false;
    id = "capture.recordToggle";
    action = global "linux-desktop:record-toggle";
    section = "UTILITIES";
    description = "Screen record";
  })
  (mk {
    keys = "SUPER + SHIFT + S";
    mainMod = false;
    id = "capture.region";
    action = global "linux-desktop:capture-region";
    section = "UTILITIES";
    description = "Screenshot";
  })
  (mk {
    keys = "SUPER + SPACE";
    mainMod = false;
    action = global "linux-desktop:launcher";
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
    keys = "SHIFT + P";
    action = dispatcher "hl.dsp.window.pin()";
    section = "WINDOWS";
    description = "Pin window";
  })
  (mk {
    keys = "CTRL + P";
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
    keys = "H";
    action = dispatcher ''hl.dsp.focus({ direction = "left" })'';
    section = "WINDOWS";
    description = "Focus left";
  })
  (mk {
    keys = "J";
    action = dispatcher ''hl.dsp.focus({ direction = "down" })'';
    section = "WINDOWS";
    description = "Focus down";
  })
  (mk {
    keys = "K";
    action = dispatcher ''hl.dsp.focus({ direction = "up" })'';
    section = "WINDOWS";
    description = "Focus up";
  })
  (mk {
    keys = "L";
    action = dispatcher ''hl.dsp.focus({ direction = "right" })'';
    section = "WINDOWS";
    description = "Focus right";
  })

  (mk {
    keys = "SHIFT + H";
    action = dispatcher ''hl.dsp.window.move({ direction = "left" })'';
    section = "WINDOWS";
    description = "Move window left";
  })
  (mk {
    keys = "SHIFT + J";
    action = dispatcher ''hl.dsp.window.move({ direction = "down" })'';
    section = "WINDOWS";
    description = "Move window down";
  })
  (mk {
    keys = "SHIFT + K";
    action = dispatcher ''hl.dsp.window.move({ direction = "up" })'';
    section = "WINDOWS";
    description = "Move window up";
  })
  (mk {
    keys = "SHIFT + L";
    action = dispatcher ''hl.dsp.window.move({ direction = "right" })'';
    section = "WINDOWS";
    description = "Move window right";
  })

  (mk {
    keys = "R";
    action = dispatcher ''
      function()
            hl.dispatch(hl.dsp.submap("resize"))
            hl.dispatch(hl.dsp.global("linux-desktop:resize-mode"))
          end'';
    section = "WINDOWS";
    description = "Resize mode";
  })
]
++ launcherResults
++ map focusWorkspace workspaceKeys
++ map moveToWorkspace workspaceKeys
++ [
  (mk {
    keys = "B";
    action = dispatcher ''hl.dsp.window.move({ monitor = "+1", follow = false })'';
    section = "DISPLAYS";
    description = "Move window to next display";
  })
  (mk {
    keys = "V";
    action = dispatcher ''hl.dsp.focus({ monitor = "+1" })'';
    section = "DISPLAYS";
    description = "Focus next display";
  })
  (mk {
    keys = "left";
    action = dispatcher ''hl.dsp.focus({ workspace = "e-1" })'';
    section = "WORKSPACES";
    description = "Previous workspace";
    label = "←";
  })
  (mk {
    keys = "right";
    action = dispatcher ''hl.dsp.focus({ workspace = "e+1" })'';
    section = "WORKSPACES";
    description = "Next workspace";
    label = "→";
  })
  (mk {
    keys = "E";
    action = exec "linux-desktop-local-scratchpad move";
    section = "WORKSPACES";
    description = "Park or restore window in this workspace's scratchpad";
  })
  (mk {
    keys = "SHIFT + E";
    action = exec "linux-desktop-local-scratchpad toggle";
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
    keys = "Caps_Lock";
    mainMod = false;
    id = "keyboard.capsLock";
    action = global "linux-desktop:keyboard-caps-lock";
    flags.non_consuming = true;
    section = "KEYBOARD";
    description = "Report compositor Caps Lock state";
    cheatsheet = false;
  })
  (mk {
    keys = "Num_Lock";
    mainMod = false;
    id = "keyboard.numLock";
    action = global "linux-desktop:keyboard-num-lock";
    flags.non_consuming = true;
    section = "KEYBOARD";
    description = "Report compositor Num Lock state";
    cheatsheet = false;
  })
  (mk {
    keys = "XF86AudioRaiseVolume";
    mainMod = false;
    id = "audio.volumeUp";
    action = global "linux-desktop:volume-up";
    flags.repeating = true;
    section = "AUDIO & MEDIA";
    description = "Volume up";
    label = "VOLUME +";
  })
  (mk {
    keys = "XF86AudioLowerVolume";
    mainMod = false;
    id = "audio.volumeDown";
    action = global "linux-desktop:volume-down";
    flags.repeating = true;
    section = "AUDIO & MEDIA";
    description = "Volume down";
    label = "VOLUME −";
  })
  (mk {
    keys = "XF86AudioMute";
    mainMod = false;
    id = "audio.toggleMute";
    action = global "linux-desktop:volume-mute";
    section = "AUDIO & MEDIA";
    description = "Mute";
    label = "MUTE";
  })
  (mk {
    keys = "N";
    id = "media.toggle";
    action = global "linux-desktop:media";
    section = "AUDIO & MEDIA";
    description = "Now playing";
  })
  (mk {
    keys = "bracketleft";
    id = "media.seekBackward";
    action = global "linux-desktop:media-seek-backward";
    flags.repeating = true;
    section = "AUDIO & MEDIA";
    description = "Seek backward 10 seconds";
    label = "[";
  })
  (mk {
    keys = "bracketright";
    id = "media.seekForward";
    action = global "linux-desktop:media-seek-forward";
    flags.repeating = true;
    section = "AUDIO & MEDIA";
    description = "Seek forward 10 seconds";
    label = "]";
  })
  (mk {
    keys = "XF86AudioPlay";
    mainMod = false;
    id = "media.playPause";
    action = global "linux-desktop:media-play-pause";
    section = "AUDIO & MEDIA";
    description = "Play / pause";
    cheatsheet = false;
  })
  (mk {
    keys = "XF86AudioNext";
    mainMod = false;
    id = "media.next";
    action = global "linux-desktop:media-next";
    section = "AUDIO & MEDIA";
    description = "Next track";
    cheatsheet = false;
  })
  (mk {
    keys = "XF86AudioPrev";
    mainMod = false;
    id = "media.previous";
    action = global "linux-desktop:media-previous";
    section = "AUDIO & MEDIA";
    description = "Previous track";
    cheatsheet = false;
  })

  (mk {
    keys = "XF86MonBrightnessUp";
    mainMod = false;
    id = "brightness.up";
    action = global "linux-desktop:brightness-up";
    flags.repeating = true;
    section = "DISPLAY";
    description = "Brightness up";
    label = "BRIGHTNESS +";
  })
  (mk {
    keys = "XF86MonBrightnessDown";
    mainMod = false;
    id = "brightness.down";
    action = global "linux-desktop:brightness-down";
    flags.repeating = true;
    section = "DISPLAY";
    description = "Brightness down";
    label = "BRIGHTNESS −";
  })
  (mk {
    keys = "O";
    id = "notifications.toggle";
    action = global "linux-desktop:notifications";
    section = "SYSTEM";
    description = "Open Activity tab";
  })
  (mk {
    keys = "SHIFT + C";
    id = "session.lock";
    action = global "linux-desktop:lock";
    section = "SYSTEM";
    description = "Lock";
  })
  (mk {
    keys = "CTRL + ALT + DELETE";
    mainMod = false;
    id = "session.toggle";
    action = global "linux-desktop:session";
    section = "SYSTEM";
    description = "Session menu";
    label = "CTRL + ALT + DELETE";
  })
  (mkMeh {
    keys = "C";
    action = app "edit-config";
    section = "SYSTEM";
    description = "Edit desktop configuration";
  })
  (mk {
    keys = "U";
    id = "home.toggle";
    action = global "linux-desktop:home";
    section = "SYSTEM";
    description = "Open Home tab";
  })
  (mk {
    keys = "I";
    id = "controls.toggle";
    action = global "linux-desktop:controls";
    section = "SYSTEM";
    description = "Open Controls tab";
  })
  (mk {
    keys = "Y";
    id = "theme.toggle";
    action = global "linux-desktop:theme";
    section = "SYSTEM";
    description = "Theme picker";
  })
  (mk {
    keys = "SHIFT + M";
    id = "animations.toggle";
    action = global "linux-desktop:animations";
    section = "SYSTEM";
    description = "Toggle animations";
  })
  (mk {
    keys = "SHIFT + G";
    id = "media.wallpaperSpectrum";
    action = global "linux-desktop:wallpaper-spectrum";
    section = "AUDIO & MEDIA";
    description = "Toggle wallpaper spectrum";
  })
  (mk {
    keys = "SHIFT + N";
    id = "media.reactiveShell";
    action = global "linux-desktop:music-reactive";
    section = "AUDIO & MEDIA";
    description = "Toggle music-reactive shell";
  })
  (mk {
    keys = "SHIFT + O";
    id = "window.effects.toggle";
    action = global "linux-desktop:window-effects";
    section = "WINDOWS";
    description = "Toggle window transparency";
  })
  (mk {
    keys = "SHIFT + B";
    id = "bar.toggle";
    action = global "linux-desktop:bar";
    section = "SYSTEM";
    description = "Toggle top bar";
  })
  (mk {
    keys = "slash";
    id = "shortcuts.toggle";
    action = global "linux-desktop:cheatsheet";
    section = "SYSTEM";
    description = "Show keyboard shortcuts";
    label = "/";
  })
  (mk {
    keys = "Escape";
    action = dispatcher ''hl.dsp.submap("passthru")'';
    section = "SYSTEM";
    description = "Enter passthrough mode";
  })
  (mk {
    keys = "H";
    mainMod = false;
    action = dispatcher "hl.dsp.window.resize({ x = -50, y = 0, relative = true })";
    flags.repeating = true;
    section = "RESIZE MODE";
    description = "Narrower";
    cheatsheet = false;
    submap = "resize";
  })
  (mk {
    keys = "J";
    mainMod = false;
    action = dispatcher "hl.dsp.window.resize({ x = 0, y = 50, relative = true })";
    flags.repeating = true;
    section = "RESIZE MODE";
    description = "Taller";
    cheatsheet = false;
    submap = "resize";
  })
  (mk {
    keys = "K";
    mainMod = false;
    action = dispatcher "hl.dsp.window.resize({ x = 0, y = -50, relative = true })";
    flags.repeating = true;
    section = "RESIZE MODE";
    description = "Shorter";
    cheatsheet = false;
    submap = "resize";
  })
  (mk {
    keys = "L";
    mainMod = false;
    action = dispatcher "hl.dsp.window.resize({ x = 50, y = 0, relative = true })";
    flags.repeating = true;
    section = "RESIZE MODE";
    description = "Wider";
    cheatsheet = false;
    submap = "resize";
  })
  (mk {
    keys = "SHIFT + H";
    mainMod = false;
    action = dispatcher "hl.dsp.window.resize({ x = 50, y = 0, relative = true })";
    flags.repeating = true;
    section = "RESIZE MODE";
    description = "Resize opposite left";
    cheatsheet = false;
    submap = "resize";
  })
  (mk {
    keys = "SHIFT + J";
    mainMod = false;
    action = dispatcher "hl.dsp.window.resize({ x = 0, y = -50, relative = true })";
    flags.repeating = true;
    section = "RESIZE MODE";
    description = "Resize opposite down";
    cheatsheet = false;
    submap = "resize";
  })
  (mk {
    keys = "SHIFT + K";
    mainMod = false;
    action = dispatcher "hl.dsp.window.resize({ x = 0, y = 50, relative = true })";
    flags.repeating = true;
    section = "RESIZE MODE";
    description = "Resize opposite up";
    cheatsheet = false;
    submap = "resize";
  })
  (mk {
    keys = "SHIFT + L";
    mainMod = false;
    action = dispatcher "hl.dsp.window.resize({ x = -50, y = 0, relative = true })";
    flags.repeating = true;
    section = "RESIZE MODE";
    description = "Resize opposite right";
    cheatsheet = false;
    submap = "resize";
  })
  (mk {
    keys = "B";
    mainMod = false;
    action = dispatcher ''hl.dsp.layout("splitratio 1.0 exact")'';
    section = "RESIZE MODE";
    description = "Balance split";
    cheatsheet = false;
    submap = "resize";
  })
  (mk {
    keys = "Escape";
    mainMod = false;
    action = dispatcher ''
      function()
            hl.dispatch(hl.dsp.submap("reset"))
            hl.dispatch(hl.dsp.global("linux-desktop:resize-mode-exit"))
          end'';
    section = "RESIZE MODE";
    description = "Exit resize mode";
    cheatsheet = false;
    submap = "resize";
  })
  (mk {
    keys = "Return";
    mainMod = false;
    action = dispatcher ''
      function()
            hl.dispatch(hl.dsp.submap("reset"))
            hl.dispatch(hl.dsp.global("linux-desktop:resize-mode-exit"))
          end'';
    section = "RESIZE MODE";
    description = "Exit resize mode";
    cheatsheet = false;
    submap = "resize";
  })
  (mk {
    keys = "R";
    mainMod = false;
    action = dispatcher ''
      function()
            hl.dispatch(hl.dsp.submap("reset"))
            hl.dispatch(hl.dsp.global("linux-desktop:resize-mode-exit"))
          end'';
    section = "RESIZE MODE";
    description = "Exit resize mode";
    cheatsheet = false;
    submap = "resize";
  })
]
