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

    Component.onCompleted: {
        armed = true;
        lockScreen.lockSession();

        if (!lockScreen.locked)
            Qt.quit();
    }

    Connections {
        target: lockScreen

        function onLockStateChanged(): void {
            if (root.armed && !lockScreen.locked)
                Qt.callLater(() => Qt.quit());
        }
    }
}
