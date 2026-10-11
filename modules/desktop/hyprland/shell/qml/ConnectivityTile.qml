pragma ComponentBehavior: Bound
import QtQuick

// Prominent live connectivity control for the hub.
// The native state owner supplies every label and activation; no local polling.
Item {
    id: tile

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property string title: ""
    property string detail: ""
    property string status: ""
    property string glyph: ""
    property string shortcut: ""
    property bool connected: false
    property color signalColor: connected ? theme.positive : theme.textMuted

    signal activated

    implicitHeight: 132
    scale: interaction.pressed ? 0.982 : interaction.containsMouse ? 1.012 : 1

    Behavior on scale {
        Anim {
            motion: tile.motion
            type: Anim.FastSpatial
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: title + ", " + detail

    ShellSurface {
        anchors.fill: parent
        theme: tile.theme
        motion: tile.motion
        surfaceLayer: ShellSurface.Group
        cornerRadius: tile.theme.radiusLarge
        fillColor: tile.connected ? Qt.tint(tile.theme.surfaceRaised, Qt.rgba(tile.theme.accent.r, tile.theme.accent.g, tile.theme.accent.b, 0.20)) : tile.theme.expressiveSurface

        ShellSurface {
            id: glyphSurface
            width: 69
            height: 69
            anchors {
                left: parent.left
                leftMargin: tile.theme.spacing4
                verticalCenter: parent.verticalCenter
            }
            theme: tile.theme
            motion: tile.motion
            surfaceLayer: ShellSurface.Control
            cornerRadius: tile.theme.radiusMedium
            fillColor: Qt.rgba(tile.signalColor.r, tile.signalColor.g, tile.signalColor.b, 0.13)

            Text {
                anchors.centerIn: parent
                text: tile.glyph
                color: tile.signalColor
                font.family: "Symbols Nerd Font"
                font.pixelSize: tile.theme.fontSize(34)
            }
        }

        Column {
            anchors {
                left: glyphSurface.right
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: tile.theme.spacing4
                rightMargin: tile.theme.spacing4
            }
            spacing: tile.theme.spacing2

            Text {
                width: parent.width
                text: tile.title
                color: tile.theme.textStrong
                font.family: tile.runtime.fontMono
                font.pixelSize: tile.theme.fontSize(18)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: tile.detail
                color: tile.theme.text
                font.family: tile.runtime.fontMono
                font.pixelSize: tile.theme.fontSize(11)
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: tile.status
                color: tile.signalColor
                font.family: tile.runtime.fontMono
                font.pixelSize: tile.theme.fontSize(9)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }

        KeyChord {
            anchors {
                top: parent.top
                right: parent.right
                margins: tile.theme.spacing2
            }
            shortcut: tile.shortcut
            fontFamily: tile.runtime.fontMono
            textColor: tile.theme.textMuted
            fontSize: tile.theme.fontKeyHint
        }
    }

    StateLayer {
        id: interaction
        theme: tile.theme
        motion: tile.motion
        selected: tile.connected
        stateColor: tile.signalColor
        cornerRadius: tile.theme.radiusLarge
        onActivated: tile.activated()
    }
}
