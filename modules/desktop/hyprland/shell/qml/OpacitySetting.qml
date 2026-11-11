pragma ComponentBehavior: Bound
import QtQuick

// A Visual Modes tile with the same surface, hover and keycap treatment as
// QuickSettingChip. The slider adjusts actual opacity without toggling the tile.
ShellSurface {
    id: setting

    required property RuntimeConfig runtime
    required property string label
    required property real opacityValue
    property string icon: ""
    property string shortcut: ""
    property bool active: false
    property bool keyboardSelected: false
    signal sliderActivated
    property color roleAccent: theme.accent

    signal toggleRequested
    signal opacityRequested(real value)

    height: 78
    Accessible.role: Accessible.Button
    Accessible.name: label + ", " + Math.round(opacityValue * 100) + "% opacity"

    scale: toggleArea.pressed ? 0.94 : tileHover.hovered ? 1.018 : 1
    Behavior on scale {
        Anim {
            motion: setting.motion
            type: Anim.FastSpatial
        }
    }

    surfaceLayer: ShellSurface.Control
    cornerRadius: active ? theme.radiusLarge : theme.radiusMedium
    // A setting can be enabled without owning the keyboard. Keep the active
    // tint/glow, but reserve the stronger outline for the selected slider;
    // otherwise an enabled Night Light looks focused after Shift+Tab leaves.
    outlined: keyboardSelected
    luminous: active || keyboardSelected
    luminousColor: roleAccent
    borderWidth: keyboardSelected ? theme.borderFocus : 0
    borderColor: keyboardSelected ? theme.blend(roleAccent, theme.textStrong, 0.55) : "transparent"
    hovered: tileHover.hovered
    fillColor: active ? theme.blend(theme.controlBase, roleAccent, theme.dark ? 0.12 : 0.08) : theme.expressiveSurfaceStrong
    Behavior on cornerRadius {
        Anim {
            motion: setting.motion
            type: Anim.FastSpatial
        }
    }

    // Only the upper content area toggles. The independent slider takes
    // pointer focus below and never turns the setting off while dragging.
    // The whole compound surface has one hover boundary, including its slider.
    // The pointer handler observes hover without intercepting child controls.
    HoverHandler {
        id: tileHover
    }

    StateLayer {
        id: toggleArea
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: setting.height - 25
        theme: setting.theme
        motion: setting.motion
        selected: setting.active
        stateColor: setting.roleAccent
        cornerRadius: setting.cornerRadius
        onActivated: setting.toggleRequested()
    }

    Column {
        anchors {
            fill: parent
            leftMargin: setting.theme.spacing2
            rightMargin: setting.theme.spacing2
            topMargin: setting.theme.spacing2
            bottomMargin: setting.theme.spacing1
        }
        spacing: setting.theme.spacing1

        Item {
            width: parent.width
            height: Math.max(setting.theme.keycapHeight - 3, setting.theme.fontSize(21))
            Text {
                anchors.centerIn: parent
                text: setting.icon
                color: setting.roleAccent
                font.family: "Symbols Nerd Font"
                font.pixelSize: setting.theme.fontSize(19)
            }
        }

        Row {
            width: parent.width
            height: 15
            spacing: setting.theme.spacing1

            Text {
                width: Math.max(1, parent.width - opacityLabel.implicitWidth - parent.spacing)
                text: setting.label
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: setting.theme.textStrong
                font.family: setting.runtime.fontMono
                font.pixelSize: setting.theme.fontSize(9)
                font.weight: setting.active ? Font.DemiBold : Font.Medium
            }
            Text {
                id: opacityLabel
                text: Math.round(setting.opacityValue * 100) + "%"
                color: setting.active ? setting.roleAccent : setting.theme.textMuted
                font.family: setting.runtime.fontMono
                font.pixelSize: setting.theme.fontSize(9)
                font.weight: Font.DemiBold
            }
        }

        ShellSlider {
            width: parent.width
            height: 19
            theme: setting.theme
            motion: setting.motion
            from: 0.20
            to: 1
            value: setting.opacityValue
            trackHeight: 6
            handleSize: 16
            accentColor: setting.roleAccent
            onInteractionStarted: setting.sliderActivated()
            onValueRequested: next => setting.opacityRequested(next)
        }
    }

    // Keep the keycap aligned to the tile, independently of icon and slider layout.
    TileKeyHint {
        visible: setting.shortcut.length > 0
        shortcut: setting.keyboardSelected ? "H/L" : setting.shortcut
        compact: true
        runtime: setting.runtime
        motion: setting.motion
        theme: setting.theme
        emphasized: setting.active || setting.keyboardSelected
        emphasisColor: setting.roleAccent
    }
}
