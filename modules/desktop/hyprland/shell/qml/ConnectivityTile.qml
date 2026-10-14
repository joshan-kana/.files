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
    property bool pending: false
    property bool scanning: false
    property bool failed: false
    property bool unavailable: false
    readonly property color signalColor: failed ? theme.critical : pending || scanning ? theme.warning : connected ? theme.accent : theme.textMuted
    readonly property color foreground: theme.textStrong

    signal activated

    implicitHeight: 92
    scale: interaction.pressed ? 0.982 : interaction.containsMouse ? 1.012 : 1

    Behavior on scale {
        Anim {
            motion: tile.motion
            type: Anim.FastSpatial
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: title + ", " + detail + ", " + status

    ShellSurface {
        anchors.fill: parent
        theme: tile.theme
        motion: tile.motion
        surfaceLayer: ShellSurface.Group
        cornerRadius: tile.theme.radiusLarge
        luminous: tile.connected || tile.pending || tile.scanning || tile.failed
        luminousColor: tile.signalColor
        hovered: interaction.containsMouse
        fillColor: tile.failed ? tile.theme.blend(tile.theme.groupBase, tile.theme.critical, 0.16) : tile.pending || tile.scanning ? tile.theme.blend(tile.theme.groupBase, tile.theme.warning, 0.14) : tile.connected ? tile.theme.blend(tile.theme.groupBase, tile.theme.accent, tile.theme.dark ? 0.34 : 0.23) : tile.unavailable ? tile.theme.groupBase : tile.theme.expressiveSurfaceStrong

        ShellSurface {
            id: glyphSurface
            width: 47
            height: 47
            anchors {
                left: parent.left
                leftMargin: tile.theme.spacing4
                verticalCenter: parent.verticalCenter
            }
            theme: tile.theme
            motion: tile.motion
            surfaceLayer: ShellSurface.Control
            cornerRadius: tile.theme.radiusMedium
            fillColor: tile.connected ? Qt.rgba(tile.theme.textStrong.r, tile.theme.textStrong.g, tile.theme.textStrong.b, 0.14) : tile.pending || tile.scanning || tile.failed ? tile.theme.blend(tile.theme.expressiveSurface, tile.signalColor, 0.17) : tile.theme.expressiveSurface

            Text {
                anchors.centerIn: parent
                text: tile.glyph
                color: tile.unavailable ? tile.theme.textMuted : tile.foreground
                font.family: "Symbols Nerd Font"
                font.pixelSize: tile.theme.fontSize(24)
            }
        }

        Column {
            anchors {
                left: glyphSurface.right
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: tile.theme.spacing4
                rightMargin: tile.theme.spacing4 + shortcutHint.implicitWidth + tile.theme.spacing2
            }
            spacing: tile.theme.spacing2

            Text {
                width: parent.width
                text: tile.title
                color: tile.foreground
                font.family: tile.runtime.fontMono
                font.pixelSize: tile.theme.fontSize(15)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: tile.detail
                color: tile.foreground
                opacity: tile.connected ? 0.76 : 0.75
                font.family: tile.runtime.fontMono
                font.pixelSize: tile.theme.fontSize(11)
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: tile.status
                color: tile.signalColor
                opacity: tile.failed || tile.pending || tile.scanning ? 1 : 0.88
                font.family: tile.runtime.fontMono
                font.pixelSize: tile.theme.fontSize(9)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }

        KeyHint {
            id: shortcutHint
            visible: tile.shortcut.length > 0
            anchors {
                top: parent.top
                right: parent.right
                margins: tile.theme.spacing3
            }
            shortcut: tile.shortcut
            compact: true
            runtime: tile.runtime
            theme: tile.theme
            emphasized: tile.connected
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
