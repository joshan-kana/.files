import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: router

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
