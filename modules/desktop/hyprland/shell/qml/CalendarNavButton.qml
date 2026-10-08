import QtQuick

ShellSurface {
    id: nav

    required property string icon

    signal activated

    implicitWidth: 34
    implicitHeight: 34
    surfaceLayer: ShellSurface.Control
    cornerRadius: theme.radiusMedium
    fillColor: hover.hovered ? theme.selectionFill : theme.layer3

    Text {
        anchors.centerIn: parent
        text: nav.icon
        color: nav.theme.textStrong
        font.family: "Symbols Nerd Font"
        font.pixelSize: nav.theme.fontSize(18)
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: nav.activated()
    }
}
