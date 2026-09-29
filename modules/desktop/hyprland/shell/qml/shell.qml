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

    AmbientBar {
        id: ambientBar
        runtime: runtime
        theme: theme
        motion: motion
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

    CommandPalette {
        id: launcher
        runtime: runtime
        theme: theme
        motion: motion
    }

    Actions {
        id: actions
        runtime: runtime
        prototype: prototype
        cheatsheet: cheatsheet
        launcher: launcher
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
