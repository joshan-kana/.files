import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: popup

    required property OsdState osd
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool closing: false
    readonly property bool keyboardMode: osd.kind === "keyboard"
    readonly property color accentColor: keyboardMode && osd.keyboardLocked ? theme.warning : osd.muted ? theme.warning : (osd.kind === "brightness" ? theme.positive : theme.accent)

    visible: true
    updatesEnabled: surfaceLifecycle.needsRendering
    PopupSurfaceLifecycle {
        id: surfaceLifecycle
        popup: popup
        exposed: popup.osd.visible || popup.closing
    }
    mask: surfaceLifecycle.inputRegion
    color: "transparent"
    implicitWidth: 370
    implicitHeight: 76
    exclusionMode: ExclusionMode.Ignore

    anchors.top: true
    margins.top: theme.panelTopOffset

    WlrLayershell.namespace: "linux-desktop-osd"

    Timer {
        id: closeTimer
        interval: popup.motion.fast
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
        anchors.fill: parent
        theme: popup.theme
        motion: popup.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusLarge
        fillColor: popup.theme.blend(popup.theme.groupBase, popup.accentColor, popup.theme.dark ? 0.07 : 0.04)

        opacity: popup.osd.visible ? 1 : 0
        scale: popup.osd.visible ? 1 : 0.97

        Behavior on opacity {
            NumberAnimation {
                duration: popup.motion.fast
                easing.type: popup.osd.visible ? popup.motion.enterType : popup.motion.exitType
                easing.bezierCurve: popup.osd.visible ? popup.motion.enterCurve : popup.motion.exitCurve
            }
        }

        Behavior on scale {
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
