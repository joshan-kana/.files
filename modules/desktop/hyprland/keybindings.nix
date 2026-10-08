{
  terminal,
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
        section
        submap
        ;
    };

  exec = value: {
    type = "exec";
    inherit value;
  };

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

  workspaceKeys = [
    {
      key = "1";
      workspace = "1";
    }
    {
      key = "2";
      workspace = "2";
    }
    {
      key = "3";
      workspace = "3";
    }
    {
      key = "4";
      workspace = "4";
    }
    {
      key = "5";
      workspace = "5";
    }
    {
      key = "6";
      workspace = "6";
    }
    {
      key = "7";
      workspace = "7";
    }
    {
      key = "8";
      workspace = "8";
    }
    {
      key = "9";
      workspace = "9";
    }
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
  (mk {
    keys = "SUPER + ALT + 1";
    mainMod = false;
    id = "terminal.open";
    action = exec terminal;
    section = "APPS";
    description = "Terminal";
  })
  (mk {
    keys = "SUPER + ALT + 2";
    mainMod = false;
    action = exec "spotify";
    section = "APPS";
    description = "Spotify";
  })
  (mk {
    keys = "SUPER + ALT + 3";
    mainMod = false;
    action = exec "brave";
    section = "APPS";
    description = "Brave";
  })
  (mk {
    keys = "SUPER + ALT + 4";
    mainMod = false;
    action = exec "floorp";
    section = "APPS";
    description = "Floorp";
  })
  (mk {
    keys = "SUPER + ALT + 5";
    mainMod = false;
    action = exec "thunderbird";
    section = "APPS";
    description = "Thunderbird";
  })
  (mk {
    keys = "SUPER + ALT + 6";
    mainMod = false;
    action = exec "code";
    section = "APPS";
    description = "Visual Studio Code";
  })
  (mk {
    keys = "SUPER + ALT + 7";
    mainMod = false;
    action = exec "obsidian --disable-gpu";
    section = "APPS";
    description = "Obsidian";
  })
  (mk {
    keys = "SUPER + ALT + E";
    mainMod = false;
    action = exec "nautilus";
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
  (mk {
    keys = "SUPER + ALT + V";
    mainMod = false;
    action = exec "[float] easyeffects";
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
    keys = "SHIFT + N";
    id = "notifications.toggle";
    action = global "linux-desktop:notifications";
    section = "SYSTEM";
    description = "Notification centre";
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
  (mk {
    keys = "SHIFT + E";
    action = exec "edit-config";
    section = "SYSTEM";
    description = "Edit desktop configuration";
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
