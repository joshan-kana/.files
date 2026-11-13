import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "FeedbackSemantics.js" as FeedbackSemantics

PanelWindow {
    id: popup

    required property OsdState osd
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property bool frameEnabled: false
    property bool barVisible: true
    property bool suspended: false
    readonly property bool exposedNow: osd.visible && !suspended
    readonly property bool screenFullscreen: Hyprland.monitorFor(screen)?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false
    readonly property bool frameConnected: frameEnabled && !screenFullscreen
    // The feedback shares the upper interaction origin with active modes.
    property real attachmentProgress: frameConnected && exposedNow ? 1 : 0
    Behavior on attachmentProgress {
        NumberAnimation {
            duration: popup.motion.morph
            easing.type: popup.motion.morphType
            easing.bezierCurve: popup.motion.morphCurve
        }
    }
    readonly property var frameBounds: ({
            x: screen ? (screen.width - width) / 2 : 0,
            y: margins.top,
            width: width,
            height: height * attachmentProgress,
            visible: frameConnected && attachmentProgress > 0.001
        })

    property bool closing: false
    readonly property bool keyboardMode: osd.kind === "keyboard"
    readonly property color accentColor: keyboardMode && osd.keyboardState !== "off" ? theme.warning : osd.muted ? theme.warning : (osd.kind === "brightness" ? theme.roleColor("warmth") : theme.roleColor("audio"))

    visible: true
    updatesEnabled: surfaceLifecycle.needsRendering
    PopupSurfaceLifecycle {
        id: surfaceLifecycle
        popup: popup
        exposed: popup.exposedNow || popup.closing || popup.attachmentProgress > 0.001
    }
    mask: surfaceLifecycle.inputRegion
    color: "transparent"
    implicitWidth: Math.max(1, Math.min(370, (screen ? screen.width : 370) - (frameConnected ? theme.frameThickness : theme.panelSideOffset) * 2))
    implicitHeight: osd.kind === "mode" ? 95 : 76
    exclusionMode: ExclusionMode.Ignore

    // Keyboard feedback and interactive modes share a consistent top anchor.
    anchors.top: true
    margins.top: frameConnected ? (barVisible ? theme.barInsetTop : theme.frameThickness) : theme.panelTopOffset

    WlrLayershell.namespace: "linux-desktop-osd"
    WlrLayershell.layer: screenFullscreen ? WlrLayer.Overlay : WlrLayer.Top

    Timer {
        id: closeTimer
        interval: popup.frameConnected ? popup.motion.morph + 16 : popup.motion.fast
        onTriggered: popup.closing = false
    }

    Connections {
        target: popup.osd

        function onVisibleChanged(): void {
            if (popup.exposedNow) {
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
            top: parent.top
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
        fillColor: popup.theme.groupBase
        borderColor: popup.theme.subtleBorder
        borderWidth: popup.frameConnected ? 0 : popup.theme.borderThin

        // Attached content appears only after the continuous frame contour
        // opens far enough to hold it. No double-painted surface or residual
        // line through the disappearing body.
        opacity: popup.frameConnected ? 1 : (popup.exposedNow ? 1 : 0)
        scale: popup.frameConnected ? 1 : (popup.exposedNow ? 1 : 0.97)

        Behavior on opacity {
            enabled: !popup.frameConnected
            NumberAnimation {
                duration: popup.motion.fast
                easing.type: popup.exposedNow ? popup.motion.enterType : popup.motion.exitType
                easing.bezierCurve: popup.exposedNow ? popup.motion.enterCurve : popup.motion.exitCurve
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
                spacing: popup.theme.spacing2

                Text {
                    width: popup.theme.fontSize(20)
                    text: FeedbackSemantics.symbol(popup.osd.kind, popup.osd.muted, popup.osd.value, popup.osd.keyboardState)
                    color: popup.accentColor
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: popup.theme.fontSize(18)
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
                    width: Math.max(0, parent.width - parent.children[0].width - parent.children[1].width - valueText.width - parent.spacing * 3)
                    height: 1
                }

                Text {
                    id: valueText
                    text: popup.osd.kind === "mode" ? "ACTIVE" : popup.keyboardMode ? FeedbackSemantics.stateLabel(popup.osd.keyboardState) : popup.osd.muted ? "MUTED" : popup.osd.value + "%"
                    color: popup.theme.textStrong
                    font.family: popup.runtime.fontMono
                    font.pixelSize: popup.theme.fontSize(12)
                    font.weight: Font.DemiBold
                }
            }

            KeyHint {
                visible: popup.osd.kind === "mode"
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                }
                runtime: popup.runtime
                theme: popup.theme
                shortcut: popup.runtime.shortcutHint("passthruExit")
                label: "Exit passthrough"
                compact: true
            }

            Rectangle {
                visible: !popup.keyboardMode && popup.osd.kind !== "mode"
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
