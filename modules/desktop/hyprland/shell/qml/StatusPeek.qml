pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Inspection never writes settings or changes the current keyboard mode.
PanelWindow {
    id: peek
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property SystemState system
    required property KeyboardState keyboard
    required property BrightnessState brightness
    required property RecordingState recording
    property bool open: false
    property bool closing: false
    property bool frameEnabled: false
    property bool barVisible: true
    property bool hubVisible: false
    property var hubBounds: ({
            visible: false
        })
    property string modeName: "Normal"
    signal closeRequested

    property real attachmentProgress: frameConnected && open ? 1 : 0
    Behavior on attachmentProgress {
        NumberAnimation {
            duration: peek.motion.morph
            easing.type: peek.motion.morphType
            easing.bezierCurve: peek.motion.morphCurve
        }
    }
    readonly property var frameBounds: ({
            x: screen ? (screen.width - width) / 2 : 0,
            y: margins.top,
            width: width,
            height: height * attachmentProgress,
            visible: frameConnected && attachmentProgress > 0.001 && open
        })
    readonly property bool frameConnected: frameEnabled && !hubVisible && !(Hyprland.monitorFor(screen)?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false)
    visible: true
    focusable: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Math.max(1, Math.min(600, (screen ? screen.width : 600) - theme.panelSideOffset * 2))
    implicitHeight: Math.min(490, Math.max(1, (screen ? screen.height : 700) - theme.panelTopOffset * 2))
    readonly property real topOffset: frameConnected ? (barVisible ? theme.barInsetTop : theme.frameThickness) : theme.panelTopOffset
    anchors.top: true
    margins.top: hubVisible && hubBounds.visible && hubBounds.y + hubBounds.height + implicitHeight + theme.spacing3 < (screen ? screen.height : 1000) ? hubBounds.y + hubBounds.height + theme.spacing3 : topOffset
    WlrLayershell.namespace: "linux-desktop-status-inspection"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    PopupSurfaceLifecycle {
        id: lifecycle
        popup: peek
        exposed: peek.open || peek.closing || peek.attachmentProgress > 0.001
    }
    updatesEnabled: lifecycle.needsRendering
    mask: lifecycle.inputRegion

    Timer {
        id: closeTimer
        interval: peek.motion.fast
        onTriggered: peek.closing = false
    }
    onOpenChanged: {
        if (open) {
            closing = false;
            closeTimer.stop();
            keyboard.refresh("inspect");
            Qt.callLater(() => contentFocus.forceActiveFocus());
        } else if (motion.enabled) {
            closing = true;
            closeTimer.restart();
        } else {
            closing = false;
        }
    }

    FocusScope {
        id: contentFocus
        anchors.fill: parent
        focus: peek.open
        enabled: peek.open
        opacity: peek.open ? 1 : 0
        Behavior on opacity {
            Anim {
                motion: peek.motion
                type: Anim.FastEffects
            }
        }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                peek.closeRequested();
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                peek.keyboard.refresh("inspect");
                peek.brightness.refresh();
                event.accepted = true;
            }
        }
        ShellSurface {
            anchors.fill: parent
            theme: peek.theme
            motion: peek.motion
            surfaceLayer: ShellSurface.Pane
            cornerRadius: peek.theme.radiusPanel
            frameConnected: peek.frameConnected
            fillColor: peek.theme.panelBase
            borderWidth: peek.frameConnected ? 0 : peek.theme.borderFocus
            borderColor: peek.theme.subtleBorder
        }
        StatusContent {
            anchors.fill: parent
            runtime: peek.runtime
            theme: peek.theme
            motion: peek.motion
            system: peek.system
            keyboard: peek.keyboard
            brightness: peek.brightness
            recording: peek.recording
            modeName: peek.modeName
        }
    }
}
