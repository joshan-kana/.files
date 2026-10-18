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
        fillColor: chip.active ? chip.theme.blend(chip.theme.controlBase, chip.activeColor, chip.theme.dark ? 0.12 : 0.08) : chip.theme.expressiveSurfaceStrong

        Behavior on cornerRadius {
            Anim {
                motion: chip.motion
                type: Anim.FastSpatial
            }
        }

        // Tiles share the same two-row layout: glyph and keycap above the
        // title. Neither the shortcut nor its placement is widget-specific.
        Column {
            anchors {
                fill: parent
                margins: chip.theme.spacing2
            }
            // The icon remains centred; give the label slightly more breathing room beneath it.
            spacing: chip.theme.spacing1 + 3

            Item {
                width: parent.width
                height: Math.max(chip.theme.keycapHeight - 3, chip.theme.fontSize(21))
                Text {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                    }
                    text: chip.icon
                    color: chip.active ? chip.activeColor : chip.theme.textStrong
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: chip.theme.fontSize(20)
                }
                KeyHint {
                    visible: chip.shortcut.length > 0
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    shortcut: chip.shortcut
                    compact: true
                    runtime: chip.runtime
                    theme: chip.theme
                    emphasized: chip.active
                }
            }

            MarqueeText {
                width: parent.width
                text: chip.title
                color: chip.theme.textStrong
                alignCenter: true
                font.family: chip.runtime.fontMono
                font.pixelSize: chip.theme.fontSize(10)
                font.weight: chip.active ? Font.DemiBold : Font.Medium
            }
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
