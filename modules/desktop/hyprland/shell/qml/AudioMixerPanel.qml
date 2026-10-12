pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panel

    required property SystemState system
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool open: false
    property bool closing: false
    property alias selectedIndex: mixer.selectedIndex
    readonly property var streams: mixer.streams

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

    WlrLayershell.namespace: "linux-desktop-audio-mixer"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Timer {
        id: closeTimer
        interval: panel.motion.normal + (panel.motion.enabled ? 24 : 0)
        onTriggered: panel.closing = false
    }

    function selectedStream(): var {
        return mixer.selectedStream();
    }
    function adjustSelected(delta: real): void {
        mixer.adjustSelected(delta);
    }
    function toggleSelectedMute(): void {
        mixer.toggleSelectedMute();
    }

    function show(): void {
        closeTimer.stop();
        open = true;
        closing = false;
    }

    function hide(): void {
        if (!open)
            return;

        // Preserve the Wayland surface until the longer spatial exit finishes.
        closing = motion.enabled;
        open = false;
        if (closing)
            closeTimer.restart();
    }

    function toggle(): void {
        if (open)
            hide();
        else
            show();
    }

    Rectangle {
        anchors.fill: parent
        color: panel.theme.scrim
        opacity: panel.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: panel.motion.fast
                easing.type: panel.open ? panel.motion.enterType : panel.motion.exitType
                easing.bezierCurve: panel.open ? panel.motion.enterCurve : panel.motion.exitCurve
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: panel.hide()
        }
    }

    ShellSurface {
        id: card
        width: Math.min(panel.width - 120, 760)
        height: Math.min(panel.height - 140, Math.max(280, mixer.implicitHeight + theme.spacing5 * 2))
        anchors.centerIn: parent
        theme: panel.theme
        motion: panel.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusPanel
        scale: panel.open ? 1 : theme.panelClosedScale
        opacity: panel.open ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: panel.motion.normal
                easing.type: panel.open ? panel.motion.enterType : panel.motion.exitType
                easing.bezierCurve: panel.open ? panel.motion.enterCurve : panel.motion.exitCurve
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: panel.motion.fast
                easing.type: panel.motion.effectsType
                easing.bezierCurve: panel.motion.effectsCurve
            }
        }

        AudioMixerContent {
            id: mixer
            anchors {
                fill: parent
                margins: panel.theme.spacing5
            }
            system: panel.system
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            active: panel.open
            onCloseRequested: panel.hide()
        }
    }
}
