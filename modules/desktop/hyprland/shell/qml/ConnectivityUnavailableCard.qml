pragma ComponentBehavior: Bound
import QtQuick

// Shared unavailable-adapter treatment for Network and Bluetooth details.
ShellSurface {
    id: card

    required property RuntimeConfig runtime
    property string statusText: ""
    property string heading: ""
    property string description: ""
    property color statusColor: theme.readableRoleColor("warning")

    implicitHeight: Math.max(160, contents.implicitHeight + theme.spacing5 * 2)
    surfaceLayer: ShellSurface.Group
    cornerRadius: theme.radiusLarge

    Column {
        id: contents
        anchors.centerIn: parent
        width: parent.width - card.theme.spacing5 * 2
        spacing: card.theme.spacing3

        Text {
            width: parent.width
            text: card.statusText
            color: card.statusColor
            font.family: card.runtime.fontSans
            font.pixelSize: card.theme.fontSupporting
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            text: card.heading
            wrapMode: Text.WordWrap
            color: card.theme.textStrong
            font.family: card.runtime.fontSans
            font.pixelSize: card.theme.fontSize(20)
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            text: card.description
            wrapMode: Text.WordWrap
            color: card.theme.textMuted
            font.family: card.runtime.fontSans
            font.pixelSize: card.theme.fontSupporting
        }
    }
}
