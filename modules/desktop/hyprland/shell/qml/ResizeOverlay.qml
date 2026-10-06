import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: overlay

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

    property bool open: false

    visible: open
    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 560
    implicitHeight: 118

    anchors {
        top: true
    }

    margins.top: theme.panelTopOffset

    WlrLayershell.namespace: "linux-desktop-resize-hints"

    SquircleSurface {
        anchors.fill: parent

        exponent: theme.squircleExponent
        cornerRadius: theme.radiusLarge
        fillColor: theme.panelFill
        borderColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.34)
        borderWidth: theme.borderThin

        Row {
            anchors {
                fill: parent
                margins: theme.spacing4
            }
            spacing: theme.spacing5

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: theme.spacing1

                Text {
                    text: "Resize"
                    color: theme.textStrong
                    font.family: runtime.fontSans
                    font.pixelSize: theme.fontSize(17)
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "Window stays focused"
                    color: theme.textMuted
                    font.family: runtime.fontSans
                    font.pixelSize: theme.fontSize(10)
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 54
                color: theme.subtleBorder
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: theme.spacing3

                Text {
                    text: "H"
                    color: theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(12)
                    font.weight: Font.Bold
                }
                Text {
                    text: "left"
                    color: theme.text
                    font.family: runtime.fontSans
                    font.pixelSize: theme.fontSize(11)
                }
                Text {
                    text: "J"
                    color: theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(12)
                    font.weight: Font.Bold
                }
                Text {
                    text: "down"
                    color: theme.text
                    font.family: runtime.fontSans
                    font.pixelSize: theme.fontSize(11)
                }
                Text {
                    text: "K"
                    color: theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(12)
                    font.weight: Font.Bold
                }
                Text {
                    text: "up"
                    color: theme.text
                    font.family: runtime.fontSans
                    font.pixelSize: theme.fontSize(11)
                }
                Text {
                    text: "L"
                    color: theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(12)
                    font.weight: Font.Bold
                }
                Text {
                    text: "right"
                    color: theme.text
                    font.family: runtime.fontSans
                    font.pixelSize: theme.fontSize(11)
                }
            }
        }

        Text {
            anchors {
                right: parent.right
                bottom: parent.bottom
                rightMargin: theme.spacing4
                bottomMargin: theme.spacing2
            }
            text: "Shift reverses  ·  B balance  ·  Enter / Esc / R done"
            color: theme.textMuted
            font.family: runtime.fontSans
            font.pixelSize: theme.fontSize(9)
        }
    }
}
