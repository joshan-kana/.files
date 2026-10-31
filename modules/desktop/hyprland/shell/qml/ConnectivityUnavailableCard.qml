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

    implicitHeight: 160
    surfaceLayer: ShellSurface.Group
    cornerRadius: theme.radiusLarge

    Column {
        anchors.centerIn: parent
        width: parent.width - card.theme.spacing5 * 2
        spacing: card.theme.spacing3

        Text {
            width: parent.width
            text: card.statusText
            color: card.statusColor
            font.family: card.runtime.fontMono
            font.pixelSize: card.theme.fontSize(11)
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            text: card.heading
            elide: Text.ElideRight
            color: card.theme.textStrong
            font.family: card.runtime.fontMono
            font.pixelSize: card.theme.fontSize(20)
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            text: card.description
            wrapMode: Text.WordWrap
            color: card.theme.textMuted
            font.family: card.runtime.fontMono
            font.pixelSize: card.theme.fontSize(10)
        }
    }
}
