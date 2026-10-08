pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: center

    required property NotificationState notificationState
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool open: false
    property bool closing: false

    visible: open || closing
    color: "transparent"
    focusable: open
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    WlrLayershell.namespace: "linux-desktop-notification-center"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Timer {
        id: closeTimer
        interval: center.motion.fast
        onTriggered: center.closing = false
    }

    function show(): void {
        closeTimer.stop();
        closing = false;
        open = true;
        content.focusKeyboard();
    }

    function hide(): void {
        open = false;
        if (motion.fast === 0)
            closing = false;
        else {
            closing = true;
            closeTimer.restart();
        }
    }

    function toggle(): void {
        if (open)
            hide();
        else
            show();
    }

    Rectangle {
        anchors.fill: parent
        color: center.theme.scrim
        opacity: center.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: center.motion.fast
                easing.type: center.open ? center.motion.enterType : center.motion.exitType
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: center.hide()
        }
    }

    ShellSurface {
        id: card
        width: Math.min(center.width - 120, 720)
        height: Math.min(center.height - 140, content.implicitHeight + center.theme.spacing5 * 2)
        anchors.centerIn: parent

        theme: center.theme
        motion: center.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusPanel

        scale: center.open ? 1 : theme.panelClosedScale
        opacity: center.open ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: center.motion.normal
                easing.type: center.motion.enterType
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: center.motion.fast
            }
        }

        NotificationContent {
            id: content
            anchors {
                fill: parent
                margins: center.theme.spacing5
            }
            notificationState: center.notificationState
            runtime: center.runtime
            theme: center.theme
            motion: center.motion
            engaged: center.open
            onCloseRequested: center.hide()
        }
    }
}
