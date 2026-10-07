import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panel

    required property QtObject media
    required property QtObject spectrum
    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

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

    WlrLayershell.namespace: "linux-desktop-media"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Timer {
        id: closeTimer
        interval: motion.fast
        onTriggered: panel.closing = false
    }

    function show(): void {
        closeTimer.stop();
        closing = false;
        open = true;
    }

    function hide(): void {
        open = false;
        if (motion.fast === 0) {
            closing = false;
        } else {
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
        color: theme.contextualScrim
        opacity: panel.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: motion.fast
                easing.type: panel.open ? motion.enterType : motion.exitType
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: panel.hide()
        }
    }

    SquircleSurface {
        id: card
        width: Math.min(panel.width - 120, 860)
        height: Math.min(panel.height - 140, 470)
        anchors.centerIn: parent
        exponent: theme.squircleExponent
        cornerRadius: theme.radiusPanel
        fillColor: theme.panelFill
        borderColor: theme.subtleBorder
        borderWidth: theme.borderThin
        scale: panel.open ? 1 : theme.panelClosedScale
        opacity: panel.open ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: motion.normal
                easing.type: motion.enterType
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: motion.fast
            }
        }

        MediaContent {
            anchors.fill: parent
            anchors.margins: theme.spacing5
            media: panel.media
            spectrum: panel.spectrum
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            engaged: panel.open
            onCloseRequested: panel.hide()
        }
    }
}
