import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "FeedbackSemantics.js" as FeedbackSemantics

PanelWindow {
    id: qmlPopup

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
            duration: qmlPopup.motion.morph
            easing.type: qmlPopup.motion.morphType
            easing.bezierCurve: qmlPopup.motion.morphCurve
        }
    }
    readonly property var frameBounds: ({
            x: screen ? (screen.width - width) / 2 : 0,
            y: effectiveTopOffset,
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
        popup: qmlPopup
        exposed: qmlPopup.exposedNow || qmlPopup.closing || qmlPopup.attachmentProgress > 0.001
    }
    mask: surfaceLifecycle.inputRegion
    color: "transparent"
    implicitWidth: Math.max(1, Math.min(370, (screen ? screen.width : 370) - (frameConnected ? theme.frameThickness : theme.panelSideOffset) * 2))
    implicitHeight: osd.kind === "mode" ? 95 : 76
    exclusionMode: ExclusionMode.Ignore

    // Keyboard feedback and interactive modes share a consistent top anchor.
    anchors.top: true
    readonly property real effectiveTopOffset: frameConnected ? (barVisible ? theme.barInsetTop : theme.frameThickness) : theme.panelTopOffset
    margins.top: effectiveTopOffset

    WlrLayershell.namespace: "desktop-shell-osd"
    WlrLayershell.layer: screenFullscreen ? WlrLayer.Overlay : WlrLayer.Top

    Timer {
        id: closeTimer
        interval: qmlPopup.frameConnected ? qmlPopup.motion.morph + 16 : qmlPopup.motion.fast
        onTriggered: qmlPopup.closing = false
    }

    Connections {
        target: qmlPopup.osd

        function onVisibleChanged(): void {
            if (qmlPopup.exposedNow) {
                closeTimer.stop();
                qmlPopup.closing = false;
            } else if (qmlPopup.motion.fast > 0) {
                qmlPopup.closing = true;
                closeTimer.restart();
            } else {
                qmlPopup.closing = false;
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
        height: qmlPopup.frameConnected ? qmlPopup.height * qmlPopup.attachmentProgress : qmlPopup.height
        clip: qmlPopup.frameConnected
        theme: qmlPopup.theme
        motion: qmlPopup.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusLarge
        frameConnected: qmlPopup.frameConnected
        fillColor: qmlPopup.theme.groupBase
        borderColor: qmlPopup.theme.subtleBorder
        borderWidth: qmlPopup.frameConnected ? 0 : qmlPopup.theme.borderThin

        // Attached content appears only after the continuous frame contour
        // opens far enough to hold it. No double-painted surface or residual
        // line through the disappearing body.
        opacity: qmlPopup.frameConnected ? 1 : (qmlPopup.exposedNow ? 1 : 0)
        scale: qmlPopup.frameConnected ? 1 : (qmlPopup.exposedNow ? 1 : 0.97)

        Behavior on opacity {
            enabled: !qmlPopup.frameConnected
            NumberAnimation {
                duration: qmlPopup.motion.fast
                easing.type: qmlPopup.exposedNow ? qmlPopup.motion.enterType : qmlPopup.motion.exitType
                easing.bezierCurve: qmlPopup.exposedNow ? qmlPopup.motion.enterCurve : qmlPopup.motion.exitCurve
            }
        }

        Behavior on scale {
            enabled: !qmlPopup.frameConnected
            NumberAnimation {
                duration: qmlPopup.motion.fast
                easing.type: qmlPopup.motion.enterType
                easing.bezierCurve: qmlPopup.motion.enterCurve
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: qmlPopup.theme.spacing4

            Row {
                anchors {
                    top: parent.top
                    right: parent.right
                    left: parent.left
                }
                spacing: qmlPopup.theme.spacing2

                Text {
                    width: qmlPopup.theme.fontSize(20)
                    text: FeedbackSemantics.symbol(qmlPopup.osd.kind, qmlPopup.osd.muted, qmlPopup.osd.value, qmlPopup.osd.keyboardState)
                    color: qmlPopup.accentColor
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: qmlPopup.theme.fontSize(18)
                }

                Text {
                    text: qmlPopup.osd.label
                    color: qmlPopup.accentColor
                    font.family: qmlPopup.runtime.fontSans
                    font.pixelSize: qmlPopup.theme.fontSize(11)
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.4
                }

                Item {
                    width: Math.max(0, parent.width - parent.children[0].width - parent.children[1].width - valueText.width - parent.spacing * 3)
                    height: 1
                }

                Text {
                    id: valueText
                    text: qmlPopup.osd.kind === "mode" ? "ACTIVE" : qmlPopup.keyboardMode ? FeedbackSemantics.stateLabel(qmlPopup.osd.keyboardState) : qmlPopup.osd.muted ? "MUTED" : qmlPopup.osd.value + "%"
                    color: qmlPopup.theme.textStrong
                    font.family: qmlPopup.runtime.fontSans
                    font.pixelSize: qmlPopup.theme.fontSize(12)
                    font.weight: Font.DemiBold
                }
            }

            KeyHint {
                visible: qmlPopup.osd.kind === "mode"
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                }
                runtime: qmlPopup.runtime
                theme: qmlPopup.theme
                shortcut: qmlPopup.runtime.shortcutHint("passthruExit")
                label: "Exit passthrough"
                compact: true
            }

            Rectangle {
                visible: !qmlPopup.keyboardMode && qmlPopup.osd.kind !== "mode"
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    left: parent.left
                }

                height: 7
                radius: height / 2
                color: qmlPopup.theme.surfaceRaised

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: parent.width * qmlPopup.osd.value / 100
                    color: qmlPopup.accentColor

                    Behavior on width {
                        NumberAnimation {
                            duration: qmlPopup.motion.fast
                            easing.type: qmlPopup.motion.enterType
                            easing.bezierCurve: qmlPopup.motion.enterCurve
                        }
                    }
                }
            }
        }
    }
}
