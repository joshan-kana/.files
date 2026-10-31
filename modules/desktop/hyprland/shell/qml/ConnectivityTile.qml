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
    readonly property color signalColor: failed ? theme.critical : pending || scanning ? theme.warning : connected ? theme.roleColor("connectivity") : theme.textMuted
    readonly property color foreground: theme.textStrong

    signal activated

    implicitHeight: 112

    Accessible.role: Accessible.Button
    Accessible.name: title + ", " + detail + ", " + status

    ShellSurface {
        anchors.fill: parent
        theme: tile.theme
        motion: tile.motion
        surfaceLayer: ShellSurface.Group
        cornerRadius: tile.connected ? tile.theme.radiusPanel : tile.theme.radiusLarge
        luminous: tile.connected || tile.pending || tile.scanning || tile.failed
        luminousColor: tile.signalColor
        hovered: interaction.containsMouse
        fillColor: tile.failed ? tile.theme.blend(tile.theme.materialContainer, tile.theme.critical, 0.22) : tile.pending || tile.scanning ? tile.theme.blend(tile.theme.materialContainer, tile.theme.warning, 0.20) : tile.connected ? tile.theme.blend(tile.theme.materialContainerHigh, tile.signalColor, tile.theme.dark ? 0.19 : 0.13) : tile.unavailable ? tile.theme.materialContainerLow : tile.theme.materialContainer

        ShellSurface {
            id: glyphSurface
            width: 56
            height: 56
            anchors {
                left: parent.left
                leftMargin: tile.theme.spacing4
                verticalCenter: parent.verticalCenter
            }
            theme: tile.theme
            motion: tile.motion
            surfaceLayer: ShellSurface.Control
            cornerRadius: tile.connected ? 28 : tile.theme.radiusSmall
            fillColor: tile.connected ? tile.signalColor : tile.theme.materialContainerHigh

            Text {
                anchors.centerIn: parent
                text: tile.glyph
                color: tile.connected ? tile.theme.background : tile.unavailable ? tile.theme.textMuted : tile.pending || tile.scanning || tile.failed ? tile.signalColor : tile.foreground
                font.family: "Symbols Nerd Font"
                font.pixelSize: tile.theme.fontSize(27)
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

            MarqueeText {
                width: parent.width
                text: tile.title
                color: tile.foreground
                font.family: tile.runtime.fontMono
                font.pixelSize: tile.theme.fontSize(17)
                font.weight: Font.DemiBold
            }

            MarqueeText {
                width: parent.width
                text: tile.detail
                color: tile.foreground
                opacity: tile.connected ? 0.76 : 0.75
                font.family: tile.runtime.fontMono
                font.pixelSize: tile.theme.fontSize(11)
            }

            MarqueeText {
                width: parent.width
                text: tile.status
                color: tile.signalColor
                opacity: tile.failed || tile.pending || tile.scanning ? 1 : 0.88
                font.family: tile.runtime.fontMono
                font.pixelSize: tile.theme.fontSize(9)
                font.weight: Font.DemiBold
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
