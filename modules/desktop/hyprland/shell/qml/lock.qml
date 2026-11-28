//@ pragma ShellId desktop-shell-lock

import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    property bool armed: false
    property bool authenticated: false

    // The existing secure lock is authoritative. The desktop notification
    // owner consumes its atomic transition marker; no polling or second lock
    // service is created.
    FileView {
        id: notificationLockState
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/desktop-shell-session-lock.state"
        blockWrites: true
        atomicWrites: true
    }

    function publishLockState(state: string): void {
        notificationLockState.setText(state + "\n");
    }

    RuntimeConfig {
        id: qmlRuntime
    }

    Theme {
        id: qmlTheme
        runtime: qmlRuntime
    }

    Motion {
        id: qmlMotion
        runtime: qmlRuntime
    }

    LockScreen {
        id: lockScreen
        runtime: qmlRuntime
        theme: qmlTheme
        motion: qmlMotion
    }

    function stopLockService(): void {
        if (!armed || !authenticated || lockScreen.locked)
            return;

        armed = false;
        // Authentication has released the lock. Keep Quickshell alive briefly
        // so the compositor can process the unlock before systemd retires it.
        Quickshell.execDetached(["systemctl", "--user", "stop", "--no-block", "desktop-shell-lock.service"]);
    }

    Timer {
        id: retireAfterUnlock
        interval: 500
        repeat: false
        onTriggered: root.stopLockService()
    }

    Component.onCompleted: {
        armed = true;
        publishLockState("requested");
        lockScreen.lockSession();
        // Acquiring the lock is asynchronous. An initially false `locked`
        // property is never grounds to terminate the process.
    }

    Connections {
        target: lockScreen

        function onUnlockAuthorized(): void {
            root.authenticated = true;
            if (!lockScreen.locked)
                root.publishLockState("unlocked");
            if (!lockScreen.locked)
                retireAfterUnlock.restart();
        }

        function onLockStateChanged(): void {
            if (root.authenticated && !lockScreen.locked) {
                root.publishLockState("unlocked");
                retireAfterUnlock.restart();
            } else if (lockScreen.locked) {
                root.publishLockState("locked");
            }
        }
    }
}
