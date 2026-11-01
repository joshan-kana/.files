import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: router

    // The IPC fullscreen event is push-driven, but Quickshell does not update
    // toplevel.lastIpcObject until an explicit refresh. Resynchronise only on
    // that event so every shell surface sees the same authoritative state.
    property Connections fullscreenEvents: Connections {
        target: Hyprland
        function onRawEvent(event): void {
            if (event.name === "fullscreen" || event.name === "fullscreenv2")
                Hyprland.refreshToplevels();
        }
    }

    readonly property var focusedScreen: {
        const focusedMonitor = Hyprland.focusedMonitor;

        if (focusedMonitor) {
            for (const screen of Quickshell.screens) {
                if (Hyprland.monitorFor(screen) === focusedMonitor)
                    return screen;
            }
        }

        for (const screen of Quickshell.screens) {
            const monitor = Hyprland.monitorFor(screen);
            if (monitor && monitor.focused)
                return screen;
        }

        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }
}
