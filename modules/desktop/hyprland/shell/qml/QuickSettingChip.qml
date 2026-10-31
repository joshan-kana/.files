pragma ComponentBehavior: Bound
import QtQuick

// One large expressive tile for all compact system modes and actions.
// State changes the shape and tonal fill; hovering never resizes the grid.
Item {
    id: chip
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property string title: ""
    property string icon: ""
    property string shortcut: ""
    property bool active: false
    property color activeColor: theme.accent
    signal activated

    implicitHeight: 104
    Accessible.role: Accessible.Button
    Accessible.name: title

    ShellSurface {
        id: tile
        anchors.fill: parent
        theme: chip.theme
        motion: chip.motion
        surfaceLayer: ShellSurface.Control
        selected: false
        cornerRadius: chip.active ? chip.theme.radiusLarge : chip.theme.radiusMedium
        fillColor: chip.active ? chip.theme.blend(chip.theme.materialContainerHigh, chip.activeColor, chip.theme.dark ? 0.28 : 0.21) : chip.theme.materialContainer
        borderColor: chip.active ? Qt.rgba(chip.activeColor.r, chip.activeColor.g, chip.activeColor.b, 0.48) : "transparent"
        borderWidth: chip.active ? chip.theme.borderThin : 0
        Behavior on cornerRadius {
            Anim {
                motion: chip.motion
                type: Anim.FastSpatial
            }
        }
        Behavior on fillColor {
            Anim {
                motion: chip.motion
                type: Anim.FastEffects
            }
        }

        ShellSurface {
            id: symbolContainer
            width: 44
            height: 44
            anchors {
                left: parent.left
                top: parent.top
                margins: chip.theme.spacing3
            }
            theme: chip.theme
            motion: chip.motion
            surfaceLayer: ShellSurface.Control
            cornerRadius: chip.active ? 22 : chip.theme.radiusSmall
            fillColor: chip.active ? chip.activeColor : chip.theme.materialContainerHigh
            Behavior on cornerRadius {
                Anim {
                    motion: chip.motion
                    type: Anim.FastSpatial
                }
            }
            Text {
                anchors.centerIn: parent
                text: chip.icon
                font.family: "Symbols Nerd Font"
                font.pixelSize: chip.theme.fontSize(23)
                color: chip.active ? chip.theme.background : chip.activeColor
            }
        }

        KeyHint {
            visible: chip.shortcut.length > 0
            anchors {
                right: parent.right
                top: parent.top
                margins: chip.theme.spacing3
            }
            shortcut: chip.shortcut
            compact: true
            runtime: chip.runtime
            theme: chip.theme
            emphasized: chip.active
            emphasisColor: chip.activeColor
        }

        Text {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: chip.theme.spacing3
            }
            height: chip.theme.fontSize(30)
            verticalAlignment: Text.AlignBottom
            horizontalAlignment: Text.AlignLeft
            text: chip.title
            textFormat: Text.PlainText
            color: chip.theme.textStrong
            font.family: chip.runtime.fontMono
            font.pixelSize: chip.theme.fontSize(11)
            font.weight: chip.active ? Font.Bold : Font.DemiBold
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    StateLayer {
        theme: chip.theme
        motion: chip.motion
        selected: chip.active
        stateColor: chip.activeColor
        cornerRadius: tile.cornerRadius
        onActivated: chip.activated()
    }
}
