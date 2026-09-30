{
  repoPath,
  terminal,
}:

let
  mk =
    {
      keys,
      action,
      section,
      description,
      mainMod ? true,
      flags ? { },
      label ? null,
      cheatsheet ? true,
    }:
    {
      inherit
        action
        cheatsheet
        description
        flags
        keys
        label
        mainMod
        section
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
    keys = "ALT + 1";
    action = exec terminal;
    section = "APPS";
    description = "Terminal";
  })
  (mk {
    keys = "ALT + 2";
    action = exec "spotify";
    section = "APPS";
    description = "Spotify";
  })
  (mk {
    keys = "ALT + 3";
    action = exec "brave";
    section = "APPS";
    description = "Brave";
  })
  (mk {
    keys = "ALT + 4";
    action = exec "floorp";
    section = "APPS";
    description = "Floorp";
  })
  (mk {
    keys = "ALT + 5";
    action = exec "thunderbird";
    section = "APPS";
    description = "Thunderbird";
  })
  (mk {
    keys = "ALT + 6";
    action = exec "code";
    section = "APPS";
    description = "Visual Studio Code";
  })
  (mk {
    keys = "ALT + 7";
    action = exec "obsidian --disable-gpu";
    section = "APPS";
    description = "Obsidian";
  })
  (mk {
    keys = "ALT + E";
    action = exec "nautilus";
    section = "APPS";
    description = "Files";
  })
  (mk {
    keys = "SHIFT + V";
    action = global "linux-desktop:audio-mixer";
    section = "AUDIO";
    description = "Application mixer";
  })
  (mk {
    keys = "ALT + V";
    action = exec "${repoPath}/scripts/audio_fx";
    section = "AUDIO";
    description = "Audio effects";
  })

  (mk {
    keys = "SPACE";
    action = global "linux-desktop:launcher";
    section = "LAUNCHERS";
    description = "Command palette";
  })
  (mk {
    keys = "V";
    action = global "linux-desktop:clipboard";
    section = "LAUNCHERS";
    description = "Clipboard history";
  })
  (mk {
    keys = "ALT + SPACE";
    mainMod = false;
    action = exec "~/repos/rofi-desktop/scripts/rofi-desktop.sh";
    section = "LAUNCHERS";
    description = "Desktop launcher";
  })

  (mk {
    keys = "Q";
    action = dispatcher "hl.dsp.window.close()";
    section = "WINDOWS";
    description = "Close window";
  })
  (mk {
    keys = "M";
    action = dispatcher "hl.dsp.exit()";
    section = "SYSTEM";
    description = "Exit Hyprland";
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
    keys = "P";
    action = dispatcher "hl.dsp.window.pseudo()";
    section = "WINDOWS";
    description = "Toggle pseudo tiling";
  })
  (mk {
    keys = "J";
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
    label = "SUPER + LMB";
  })
  (mk {
    keys = "mouse:273";
    action = dispatcher "hl.dsp.window.resize()";
    flags.mouse = true;
    section = "WINDOWS";
    description = "Resize window";
    label = "SUPER + RMB";
  })

  (mk {
    keys = "A";
    action = dispatcher ''hl.dsp.focus({ direction = "l" })'';
    section = "FOCUS";
    description = "Focus left";
  })
  (mk {
    keys = "D";
    action = dispatcher ''hl.dsp.focus({ direction = "r" })'';
    section = "FOCUS";
    description = "Focus right";
  })
  (mk {
    keys = "W";
    action = dispatcher ''hl.dsp.focus({ direction = "u" })'';
    section = "FOCUS";
    description = "Focus up";
  })
  (mk {
    keys = "S";
    action = dispatcher ''hl.dsp.focus({ direction = "d" })'';
    section = "FOCUS";
    description = "Focus down";
  })
]
++ map focusWorkspace workspaceKeys
++ map moveToWorkspace workspaceKeys
++ [
  (mk {
    keys = "SHIFT + D";
    action = dispatcher "hl.dsp.window.resize({ x = 50, y = 0, relative = true })";
    flags.repeating = true;
    section = "WINDOWS";
    description = "Grow window right";
  })
  (mk {
    keys = "SHIFT + A";
    action = dispatcher "hl.dsp.window.resize({ x = -50, y = 0, relative = true })";
    flags.repeating = true;
    section = "WINDOWS";
    description = "Shrink window right";
  })
  (mk {
    keys = "SHIFT + W";
    action = dispatcher "hl.dsp.window.resize({ x = 0, y = -50, relative = true })";
    flags.repeating = true;
    section = "WINDOWS";
    description = "Shrink window down";
  })
  (mk {
    keys = "SHIFT + S";
    action = dispatcher "hl.dsp.window.resize({ x = 0, y = 50, relative = true })";
    flags.repeating = true;
    section = "WINDOWS";
    description = "Grow window down";
  })
  (mk {
    keys = "X";
    action = dispatcher ''hl.dsp.workspace.toggle_special("magic")'';
    section = "WORKSPACES";
    description = "Toggle special workspace";
  })
  (mk {
    keys = "SHIFT + X";
    action = dispatcher ''hl.dsp.window.move({ workspace = "special:magic", follow = true })'';
    section = "WORKSPACES";
    description = "Move window to special workspace";
  })
  (mk {
    keys = "mouse_down";
    action = dispatcher ''hl.dsp.focus({ workspace = "e+1" })'';
    section = "WORKSPACES";
    description = "Next workspace";
    label = "SUPER + WHEEL ↓";
  })
  (mk {
    keys = "mouse_up";
    action = dispatcher ''hl.dsp.focus({ workspace = "e-1" })'';
    section = "WORKSPACES";
    description = "Previous workspace";
    label = "SUPER + WHEEL ↑";
  })
  (mk {
    keys = "CTRL + A";
    action = dispatcher ''hl.dsp.focus({ workspace = "e-1" })'';
    section = "WORKSPACES";
    description = "Previous workspace";
  })
  (mk {
    keys = "CTRL + D";
    action = dispatcher ''hl.dsp.focus({ workspace = "e+1" })'';
    section = "WORKSPACES";
    description = "Next workspace";
  })

  (mk {
    keys = "XF86AudioRaiseVolume";
    mainMod = false;
    action = global "linux-desktop:volume-up";
    flags.repeating = true;
    section = "AUDIO";
    description = "Volume up";
    label = "VOLUME +";
  })
  (mk {
    keys = "XF86AudioLowerVolume";
    mainMod = false;
    action = global "linux-desktop:volume-down";
    flags.repeating = true;
    section = "AUDIO";
    description = "Volume down";
    label = "VOLUME −";
  })
  (mk {
    keys = "XF86AudioMute";
    mainMod = false;
    action = global "linux-desktop:volume-mute";
    section = "AUDIO";
    description = "Mute";
    label = "MUTE";
  })
  (mk {
    keys = "ALT + X";
    action = exec "playerctl play-pause";
    section = "MEDIA";
    description = "Play / pause";
  })
  (mk {
    keys = "ALT + C";
    action = exec "playerctl next";
    section = "MEDIA";
    description = "Next track";
  })
  (mk {
    keys = "ALT + Z";
    action = exec "playerctl previous";
    section = "MEDIA";
    description = "Previous track";
  })
  (mk {
    keys = "ALT + D";
    action = exec "playerctl position 10+";
    flags.repeating = true;
    section = "MEDIA";
    description = "Seek forward 10 seconds";
  })
  (mk {
    keys = "ALT + S";
    action = exec "playerctl position 10-";
    flags.repeating = true;
    section = "MEDIA";
    description = "Seek backward 10 seconds";
  })
  (mk {
    keys = "ALT + W";
    action = exec "playerctl shuffle toggle";
    section = "MEDIA";
    description = "Toggle shuffle";
  })
  (mk {
    keys = "ALT + F";
    action = exec "playerctld shift";
    section = "MEDIA";
    description = "Switch media player";
  })

  (mk {
    keys = "XF86MonBrightnessUp";
    mainMod = false;
    action = global "linux-desktop:brightness-up";
    flags.repeating = true;
    section = "DISPLAY";
    description = "Brightness up";
    label = "BRIGHTNESS +";
  })
  (mk {
    keys = "XF86MonBrightnessDown";
    mainMod = false;
    action = global "linux-desktop:brightness-down";
    flags.repeating = true;
    section = "DISPLAY";
    description = "Brightness down";
    label = "BRIGHTNESS −";
  })
  (mk {
    keys = "L";
    action = exec "swaylock";
    section = "SYSTEM";
    description = "Lock";
  })
  (mk {
    keys = "SHIFT + E";
    action = exec "code ${repoPath}/edit_config.code-workspace";
    section = "SYSTEM";
    description = "Edit desktop configuration";
  })
  (mk {
    keys = "/";
    action = global "linux-desktop:cheatsheet";
    section = "SYSTEM";
    description = "Show keyboard shortcuts";
  })
  (mk {
    keys = "Escape";
    action = dispatcher ''hl.dsp.submap("passthru")'';
    section = "SYSTEM";
    description = "Enter passthrough mode";
  })
]
