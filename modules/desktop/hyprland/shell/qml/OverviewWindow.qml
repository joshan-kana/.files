pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellSurface {
    id: tile

    required property var toplevel
    required property RuntimeConfig runtime
    property bool active: false
    signal activated

    surfaceLayer: ShellSurface.Control
    cornerRadius: theme.radiusMedium
    fillColor: selected ? theme.selectionFill : theme.layer2
    borderColor: selected ? theme.accent : theme.subtleBorder
    borderWidth: selected ? theme.borderFocus : theme.borderThin

    Column {
        anchors {
            fill: parent
            margins: tile.theme.spacing3
        }
        spacing: tile.theme.spacing2

        Row {
            width: parent.width
            spacing: tile.theme.spacing2
            Image {
                width: 22
                height: 22
                source: Quickshell.iconPath(tile.toplevel && tile.toplevel.lastIpcObject ? tile.toplevel.lastIpcObject.class || "" : "", "application-x-executable")
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
            Text {
                width: Math.max(1, parent.width - 30)
                text: tile.toplevel ? (tile.toplevel.title || tile.toplevel.lastIpcObject.class || "Window") : "Window"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: tile.runtime.fontMono
                font.pixelSize: tile.theme.fontSize(11)
                color: tile.theme.textStrong
            }
        }

        Item {
            width: parent.width
            height: Math.max(1, parent.height - 30)
            clip: true

            ScreencopyView {
                anchors.fill: parent
                captureSource: tile.active && tile.toplevel && tile.toplevel.wayland ? tile.toplevel.wayland : null
                constraintSize: Qt.size(Math.max(1, width), Math.max(1, height))
                live: tile.active
                paintCursor: false
            }

            Text {
                anchors.centerIn: parent
                visible: !tile.toplevel || !tile.toplevel.wayland
                text: "PREVIEW UNAVAILABLE"
                color: tile.theme.textMuted
                font.family: tile.runtime.fontMono
                font.pixelSize: tile.theme.fontSize(10)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.activated()
    }
}
