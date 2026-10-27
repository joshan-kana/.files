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

    Item {
        id: preview
        anchors {
            fill: parent
            margins: tile.theme.spacing2
        }
        clip: true

        // Keep native compositor screencopy as the window preview source.
        // Only exposed tiles request frames; no screenshot cache or daemon.
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

        ShellSurface {
            anchors {
                right: parent.right
                top: parent.top
                margins: tile.theme.spacing2
            }
            width: 52
            height: 30
            theme: tile.theme
            motion: tile.motion
            surfaceLayer: ShellSurface.Control
            cornerRadius: theme.radiusSmall
            fillColor: theme.paneBase
            visible: !!tile.toplevel && !!tile.toplevel.workspace
            Text {
                anchors.centerIn: parent
                text: "WS " + (tile.toplevel && tile.toplevel.workspace ? tile.toplevel.workspace.id : "")
                color: tile.theme.textStrong
                font.family: tile.runtime.fontMono
                font.pixelSize: tile.theme.fontSize(10)
                font.weight: Font.DemiBold
            }
        }

        ShellSurface {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 42
            theme: tile.theme
            motion: tile.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: theme.radiusSmall
            fillColor: theme.paneBase

            Row {
                anchors {
                    fill: parent
                    leftMargin: tile.theme.spacing3
                    rightMargin: tile.theme.spacing3
                }
                spacing: tile.theme.spacing2
                Image {
                    width: 24
                    height: 24
                    anchors.verticalCenter: parent.verticalCenter
                    source: Quickshell.iconPath(tile.toplevel && tile.toplevel.lastIpcObject ? tile.toplevel.lastIpcObject.class || "" : "", "application-x-executable")
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                MarqueeText {
                    width: Math.max(1, parent.width - 24 - parent.spacing)
                    anchors.verticalCenter: parent.verticalCenter
                    text: tile.toplevel ? (tile.toplevel.title || tile.toplevel.lastIpcObject.class || "Window") : "Window"
                    textFormat: Text.PlainText
                    font.family: tile.runtime.fontMono
                    font.pixelSize: tile.theme.fontSize(12)
                    color: tile.theme.textStrong
                }
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
