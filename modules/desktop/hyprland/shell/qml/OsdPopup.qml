import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: popup

    required property QtObject osd
    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

    property bool closing: false
    readonly property color accentColor: osd.muted
        ? theme.warning
        : (osd.kind === "brightness" ? theme.positive : theme.accent)

    visible: osd.visible || closing
    color: "transparent"
    implicitWidth: 370
    implicitHeight: 76
    exclusionMode: ExclusionMode.Ignore

    anchors.top: true
    margins.top: 82

    WlrLayershell.namespace: "linux-desktop-osd"

    Timer {
        id: closeTimer
        interval: motion.fast
        onTriggered: popup.closing = false
    }

    Connections {
        target: osd

        function onVisibleChanged(): void {
            if (osd.visible) {
                closeTimer.stop();
                popup.closing = false;
            } else if (motion.fast > 0) {
                popup.closing = true;
                closeTimer.restart();
            } else {
                popup.closing = false;
            }
        }
    }

    SquircleSurface {
        anchors.fill: parent

        exponent: theme.squircleExponent
        cornerRadius: theme.radiusLarge
        fillColor: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.985)
        borderColor: Qt.rgba(popup.accentColor.r, popup.accentColor.g, popup.accentColor.b, 0.44)
        borderWidth: theme.borderThin

        opacity: osd.visible ? 1 : 0
        scale: osd.visible ? 1 : 0.97

        Behavior on opacity {
            NumberAnimation {
                duration: motion.fast
                easing.type: osd.visible ? motion.enterType : motion.exitType
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: motion.fast
                easing.type: motion.enterType
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: theme.spacing4

            Row {
                anchors {
                    top: parent.top
                    right: parent.right
                    left: parent.left
                }

                Text {
                    text: osd.label
                    color: popup.accentColor
                    font.family: runtime.fontMono
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.4
                }

                Item {
                    width: parent.width - parent.children[0].width - valueText.width
                    height: 1
                }

                Text {
                    id: valueText
                    text: osd.value + "%"
                    color: theme.textStrong
                    font.family: runtime.fontMono
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }

            Rectangle {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    left: parent.left
                }

                height: 7
                radius: height / 2
                color: theme.surfaceRaised

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: parent.width * osd.value / 100
                    color: popup.accentColor

                    Behavior on width {
                        NumberAnimation {
                            duration: motion.fast
                            easing.type: motion.enterType
                        }
                    }
                }
            }
        }
    }
}
