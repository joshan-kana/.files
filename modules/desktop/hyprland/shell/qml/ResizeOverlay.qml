import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: overlay

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool open: false

    visible: true
    updatesEnabled: surfaceLifecycle.needsRendering
    PopupSurfaceLifecycle {
        id: surfaceLifecycle
        popup: overlay
        exposed: overlay.open
    }
    mask: surfaceLifecycle.inputRegion
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

    ShellSurface {
        anchors.fill: parent
        theme: overlay.theme
        motion: overlay.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusLarge

        Row {
            anchors {
                fill: parent
                margins: overlay.theme.spacing4
            }
            spacing: overlay.theme.spacing5

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: overlay.theme.spacing1

                Text {
                    text: "Resize"
                    color: overlay.theme.textStrong
                    font.family: overlay.runtime.fontMono
                    font.pixelSize: overlay.theme.fontSize(17)
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "Window stays focused"
                    color: overlay.theme.textMuted
                    font.family: overlay.runtime.fontMono
                    font.pixelSize: overlay.theme.fontSize(10)
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 54
                color: overlay.theme.subtleBorder
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: overlay.theme.spacing3

                Text {
                    text: "H"
                    color: overlay.theme.accent
                    font.family: overlay.runtime.fontMono
                    font.pixelSize: overlay.theme.fontSize(12)
                    font.weight: Font.Bold
                }
                Text {
                    text: "left"
                    color: overlay.theme.text
                    font.family: overlay.runtime.fontMono
                    font.pixelSize: overlay.theme.fontSize(11)
                }
                Text {
                    text: "J"
                    color: overlay.theme.accent
                    font.family: overlay.runtime.fontMono
                    font.pixelSize: overlay.theme.fontSize(12)
                    font.weight: Font.Bold
                }
                Text {
                    text: "down"
                    color: overlay.theme.text
                    font.family: overlay.runtime.fontMono
                    font.pixelSize: overlay.theme.fontSize(11)
                }
                Text {
                    text: "K"
                    color: overlay.theme.accent
                    font.family: overlay.runtime.fontMono
                    font.pixelSize: overlay.theme.fontSize(12)
                    font.weight: Font.Bold
                }
                Text {
                    text: "up"
                    color: overlay.theme.text
                    font.family: overlay.runtime.fontMono
                    font.pixelSize: overlay.theme.fontSize(11)
                }
                Text {
                    text: "L"
                    color: overlay.theme.accent
                    font.family: overlay.runtime.fontMono
                    font.pixelSize: overlay.theme.fontSize(12)
                    font.weight: Font.Bold
                }
                Text {
                    text: "right"
                    color: overlay.theme.text
                    font.family: overlay.runtime.fontMono
                    font.pixelSize: overlay.theme.fontSize(11)
                }
            }
        }

        Text {
            anchors {
                right: parent.right
                bottom: parent.bottom
                rightMargin: overlay.theme.spacing4
                bottomMargin: overlay.theme.spacing2
            }
            text: "Shift reverses  ·  B balance  ·  Enter / Esc / R done"
            color: overlay.theme.textMuted
            font.family: overlay.runtime.fontMono
            font.pixelSize: overlay.theme.fontSize(9)
        }
    }
}
