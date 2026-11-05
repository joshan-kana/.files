//@ pragma ShellId linux-desktop-lock

import QtQuick
import Quickshell

ShellRoot {
    id: root

    property bool armed: false

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

    LockScreen {
        id: lockScreen
        runtime: runtime
        theme: theme
        motion: motion
    }

    function stopLockService(): void {
        if (!armed)
            return;

        armed = false;
        // The Wayland lock is already released; retire its process too so
        // systemd permits another lock during this desktop session.
        Qt.callLater(() => Quickshell.execDetached(["systemctl", "--user", "stop", "--no-block", "linux-desktop-lock.service"]));
    }

    Component.onCompleted: {
        armed = true;
        lockScreen.lockSession();
        if (!lockScreen.locked)
            stopLockService();
    }

    Connections {
        target: lockScreen

        function onLockStateChanged(): void {
            if (root.armed && !lockScreen.locked)
                root.stopLockService();
        }
    }
}
