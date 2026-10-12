pragma ComponentBehavior: Bound
import QtQuick

// Compact, live-state action for the Controls strip. The caller owns the action.
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

    implicitHeight: 66
    Accessible.role: Accessible.Button
    Accessible.name: title

    scale: press.pressed ? 0.94 : press.containsMouse ? 1.018 : 1
    Behavior on scale {
        Anim {
            motion: chip.motion
            type: Anim.FastSpatial
        }
    }

    ShellSurface {
        anchors.fill: parent
        theme: chip.theme
        motion: chip.motion
        surfaceLayer: ShellSurface.Control
        cornerRadius: chip.active ? chip.theme.radiusLarge : chip.theme.radiusMedium
        luminous: chip.active
        luminousColor: chip.activeColor
        hovered: press.containsMouse
        fillColor: chip.active ? chip.theme.blend(chip.theme.controlBase, chip.activeColor, chip.theme.dark ? 0.19 : 0.13) : chip.theme.expressiveSurfaceStrong

        Behavior on cornerRadius {
            Anim {
                motion: chip.motion
                type: Anim.FastSpatial
            }
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - chip.theme.spacing2 * 2
            spacing: chip.theme.spacing1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: chip.icon
                color: chip.active ? chip.activeColor : chip.theme.textStrong
                font.family: "Symbols Nerd Font"
                font.pixelSize: chip.theme.fontSize(21)
            }

            Text {
                width: parent.width
                text: chip.title
                color: chip.theme.textStrong
                horizontalAlignment: Text.AlignHCenter
                font.family: chip.runtime.fontMono
                font.pixelSize: chip.theme.fontSize(10)
                font.weight: chip.active ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
            }
        }

        KeyChord {
            visible: chip.shortcut.length > 0
            anchors {
                top: parent.top
                right: parent.right
                margins: chip.theme.spacing3
            }
            shortcut: chip.shortcut
            fontFamily: chip.runtime.fontMono
            textColor: chip.theme.textMuted
            fontSize: chip.theme.fontSize(8)
        }
    }

    StateLayer {
        id: press
        theme: chip.theme
        motion: chip.motion
        selected: chip.active
        stateColor: chip.activeColor
        cornerRadius: chip.theme.radiusMedium
        onActivated: chip.activated()
    }
}
