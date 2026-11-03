import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: popup

    required property OsdState osd
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property bool frameEnabled: false
    readonly property bool frameConnected: frameEnabled && !(Hyprland.monitorFor(screen)?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false)
    // The contour itself grows from the bottom edge; it does not wait for a
    // completed panel to appear and then snap an outline around it.
    property real attachmentProgress: frameConnected && osd.visible ? 1 : 0
    Behavior on attachmentProgress {
        NumberAnimation {
            duration: popup.motion.morph
            easing.type: popup.motion.morphType
            easing.bezierCurve: popup.motion.morphCurve
        }
    }
    readonly property var frameBounds: ({
            x: screen ? (screen.width - width) / 2 : 0,
            y: screen ? screen.height - theme.frameThickness - height * attachmentProgress : 0,
            width: width,
            height: height * attachmentProgress,
            visible: frameConnected && attachmentProgress > 0.001
        })

    property bool closing: false
    readonly property bool keyboardMode: osd.kind === "keyboard"
    readonly property color accentColor: keyboardMode && osd.keyboardLocked ? theme.warning : osd.muted ? theme.warning : (osd.kind === "brightness" ? theme.roleColor("warmth") : theme.roleColor("audio"))

    visible: true
    updatesEnabled: surfaceLifecycle.needsRendering
    PopupSurfaceLifecycle {
        id: surfaceLifecycle
        popup: popup
        exposed: popup.osd.visible || popup.closing || popup.attachmentProgress > 0.001
    }
    mask: surfaceLifecycle.inputRegion
    color: "transparent"
    implicitWidth: Math.max(1, Math.min(370, (screen ? screen.width : 370) - (frameConnected ? theme.frameThickness : theme.panelSideOffset) * 2))
    implicitHeight: 76
    exclusionMode: ExclusionMode.Ignore

    // Centre the OSD at the bottom in both modes, below the Controls hub.
    anchors.bottom: true
    margins.bottom: frameConnected ? theme.frameThickness : theme.panelSideOffset

    WlrLayershell.namespace: "linux-desktop-osd"

    Timer {
        id: closeTimer
        interval: popup.frameConnected ? popup.motion.morph + 16 : popup.motion.fast
        onTriggered: popup.closing = false
    }

    Connections {
        target: popup.osd

        function onVisibleChanged(): void {
            if (popup.osd.visible) {
                closeTimer.stop();
                popup.closing = false;
            } else if (popup.motion.fast > 0) {
                popup.closing = true;
                closeTimer.restart();
            } else {
                popup.closing = false;
            }
        }
    }

    ShellSurface {
        id: osdSurface
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        // Content is clipped by the very same extent used by the joined
        // frame contour. Nothing fades away before an independent outline.
        height: popup.frameConnected ? popup.height * popup.attachmentProgress : popup.height
        clip: popup.frameConnected
        theme: popup.theme
        motion: popup.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusLarge
        frameConnected: popup.frameConnected
        fillColor: popup.frameConnected && !popup.theme.shellGlassEnabled ? "transparent" : popup.theme.groupBase
        borderColor: popup.theme.subtleBorder
        borderWidth: popup.frameConnected ? 0 : popup.theme.borderThin

        // Attached content appears only after the continuous frame contour
        // opens far enough to hold it. No double-painted surface or residual
        // line through the disappearing body.
        opacity: popup.frameConnected ? 1 : (popup.osd.visible ? 1 : 0)
        scale: popup.frameConnected ? 1 : (popup.osd.visible ? 1 : 0.97)

        Behavior on opacity {
            enabled: !popup.frameConnected
            NumberAnimation {
                duration: popup.motion.fast
                easing.type: popup.osd.visible ? popup.motion.enterType : popup.motion.exitType
                easing.bezierCurve: popup.osd.visible ? popup.motion.enterCurve : popup.motion.exitCurve
            }
        }

        Behavior on scale {
            enabled: !popup.frameConnected
            NumberAnimation {
                duration: popup.motion.fast
                easing.type: popup.motion.enterType
                easing.bezierCurve: popup.motion.enterCurve
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: popup.theme.spacing4

            Row {
                anchors {
                    top: parent.top
                    right: parent.right
                    left: parent.left
                }

                Text {
                    text: popup.osd.label
                    color: popup.accentColor
                    font.family: popup.runtime.fontMono
                    font.pixelSize: popup.theme.fontSize(11)
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.4
                }

                Item {
                    width: parent.width - parent.children[0].width - valueText.width
                    height: 1
                }

                Text {
                    id: valueText
                    text: popup.keyboardMode ? (popup.osd.keyboardLocked ? "󰪛  ON" : "󰪜  OFF") : popup.osd.value + "%"
                    color: popup.theme.textStrong
                    font.family: popup.runtime.fontMono
                    font.pixelSize: popup.theme.fontSize(12)
                    font.weight: Font.DemiBold
                }
            }

            Rectangle {
                visible: !popup.keyboardMode
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    left: parent.left
                }

                height: 7
                radius: height / 2
                color: popup.theme.surfaceRaised

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: parent.width * popup.osd.value / 100
                    color: popup.accentColor

                    Behavior on width {
                        NumberAnimation {
                            duration: popup.motion.fast
                            easing.type: popup.motion.enterType
                            easing.bezierCurve: popup.motion.enterCurve
                        }
                    }
                }
            }
        }
    }
}
