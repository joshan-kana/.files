//@ pragma ShellId linux-desktop

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

ShellRoot {
    id: root

    RuntimeConfig {
        id: runtime
    }

    Theme {
        id: theme
        runtime: runtime
    }

    Motion {
        id: motion
        runtime: runtime
    }

    MediaState {
        id: media
    }

    AmbientBar {
        id: ambientBar
        runtime: runtime
        theme: theme
        motion: motion
        media: media
        onMediaRequested: actions.toggleMedia()
    }

    PrototypeSurface {
        id: prototype
        runtime: runtime
        theme: theme
    }

    ShortcutCheatsheet {
        id: cheatsheet
        runtime: runtime
        theme: theme
        motion: motion
    }

    MediaPanel {
        id: mediaPanel
        media: media
        runtime: runtime
        theme: theme
        motion: motion
    }

    CommandPalette {
        id: launcher
        runtime: runtime
        theme: theme
        motion: motion
        commands: [
            { id: "media.toggle", name: "Now Playing", description: "Open media controls", icon: "multimedia-player", keywords: ["music", "spotify", "media"] },
            { id: "shortcuts.toggle", name: "Keyboard Shortcuts", description: "Show the Hyprland key map", icon: "preferences-desktop-keyboard-shortcuts", key: "SUPER + /", keywords: ["keybinds", "cheatsheet"] },
            { id: "animations.toggle", name: "Toggle Animations", description: "Enable or disable desktop motion", icon: "preferences-desktop-effects", keywords: ["motion", "reduce motion"] },
            { id: "terminal.open", name: "Open Terminal", description: runtime.terminal, icon: "utilities-terminal", keywords: ["shell", "console"] }
        ]
        onCommandTriggered: commandId => actions.invokeCommand(commandId)
    }

    Actions {
        id: actions
        runtime: runtime
        prototype: prototype
        cheatsheet: cheatsheet
        launcher: launcher
        mediaPanel: mediaPanel
        motion: motion
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "cheatsheet"
        description: "Show Hyprland keyboard shortcuts"
        onPressed: actions.toggleCheatsheet()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "launcher"
        description: "Open command palette"
        onPressed: actions.toggleLauncher()
    }

    GlobalShortcut {
        appid: "linux-desktop"
        name: "media"
        description: "Open now playing"
        onPressed: actions.toggleMedia()
    }

    IpcHandler {
        target: "desktop"

        function showPrototype(): void {
            actions.showPrototype();
        }

        function hidePrototype(): void {
            actions.hidePrototype();
        }

        function togglePrototype(): void {
            actions.togglePrototype();
        }

        function toggleCheatsheet(): void {
            actions.toggleCheatsheet();
        }

        function toggleLauncher(): void {
            actions.toggleLauncher();
        }

        function toggleMedia(): void {
            actions.toggleMedia();
        }

        function toggleAnimations(): void {
            actions.toggleAnimations();
        }

        function animationsEnabled(): bool {
            return motion.enabled;
        }

        function launchTerminal(): void {
            actions.launchTerminal();
        }

        function terminal(): string {
            return runtime.terminal;
        }
    }
}
