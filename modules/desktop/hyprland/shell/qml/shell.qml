//@ pragma ShellId linux-desktop

import QtQuick
import Quickshell
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

    PrototypeSurface {
        id: prototype
        runtime: runtime
        theme: theme
    }

    Actions {
        id: actions
        runtime: runtime
        prototype: prototype
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

        function launchTerminal(): void {
            actions.launchTerminal();
        }

        function terminal(): string {
            return runtime.terminal;
        }
    }
}
