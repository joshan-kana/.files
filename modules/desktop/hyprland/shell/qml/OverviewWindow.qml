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
    signal dragMoved(real pointerX, real pointerY)
    signal dropped(real pointerX, real pointerY)

    surfaceLayer: ShellSurface.Control
    cornerRadius: theme.radiusMedium
    fillColor: selected ? theme.blend(theme.layer2, theme.accent, theme.dark ? 0.075 : 0.045) : theme.layer2
    borderColor: selected ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.72) : theme.subtleBorder
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
            MarqueeText {
                width: Math.max(1, parent.width - 30)
                text: tile.toplevel ? (tile.toplevel.title || tile.toplevel.lastIpcObject.class || "Window") : "Window"
                textFormat: Text.PlainText
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
        id: interaction
        anchors.fill: parent
        cursorShape: dragActive ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        property real pressedX: 0
        property real pressedY: 0
        property bool dragActive: false
        onPressed: mouse => {
            pressedX = mouse.x;
            pressedY = mouse.y;
            dragActive = false;
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            if (!dragActive && Math.hypot(mouse.x - pressedX, mouse.y - pressedY) >= 10)
                dragActive = true;
            if (dragActive)
                tile.dragMoved(mouse.x, mouse.y);
        }
        onReleased: mouse => {
            if (dragActive)
                tile.dropped(mouse.x, mouse.y);
        }
        onClicked: {
            if (!dragActive)
                tile.activated();
            dragActive = false;
        }
        onCanceled: dragActive = false
    }
}
