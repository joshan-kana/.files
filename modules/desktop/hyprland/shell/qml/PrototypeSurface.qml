import QtQuick
import Quickshell

PanelWindow {
    id: window

    required property QtObject runtime
    required property QtObject theme

    visible: false
    color: "transparent"
    implicitWidth: 420
    implicitHeight: 116
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
    }

    margins {
        top: theme.spacing5
        right: theme.spacing5
    }

    Rectangle {
        anchors.fill: parent
        radius: theme.radiusLarge
        color: theme.surface
        border.width: 1
        border.color: theme.outline

        Rectangle {
            id: accent
            width: 5
            radius: width / 2
            color: theme.accent

            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                topMargin: theme.spacing4
                bottomMargin: theme.spacing4
                leftMargin: theme.spacing4
            }
        }

        Column {
            spacing: theme.spacing2

            anchors {
                verticalCenter: parent.verticalCenter
                left: accent.right
                right: parent.right
                leftMargin: theme.spacing4
                rightMargin: theme.spacing4
            }

            Text {
                text: "Linux desktop prototype"
                color: theme.textStrong
                font.family: runtime.fontSans
                font.pixelSize: theme.fontSize(18)
                font.weight: Font.DemiBold
            }

            Text {
                text: "Policy is live · terminal: " + runtime.terminal
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(13)
            }
        }
    }
}
