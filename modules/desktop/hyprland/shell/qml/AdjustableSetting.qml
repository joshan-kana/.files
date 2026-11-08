pragma ComponentBehavior: Bound
import QtQuick

// Shared Controls tile: toggle on the header, adjust by dragging the native
// slider or via the same selected-slider keyboard workflow as transparency.
ShellSurface {
    id: setting
    required property RuntimeConfig runtime
    required property string label
    required property string valueText
    property string icon: ""
    property string toggleShortcut: ""
    property bool active: false
    property bool canToggle: true
    property bool canAdjust: true
    property bool keyboardSelected: false
    property real from: 2500
    property real to: 6500
    property real value: from
    property color roleAccent: theme.accent
    signal toggleRequested
    signal valueRequested(real value)
    signal sliderActivated

    height: 78
    Accessible.role: Accessible.Button
    Accessible.name: label + ", " + valueText + (active ? ", on" : ", off")
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

    // The whole compound surface has one hover boundary, including its slider.
    // The pointer handler observes hover without intercepting child controls.
    HoverHandler {
        id: tileHover
    }

    StateLayer {
        id: toggleArea
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: setting.height - 25
        theme: setting.theme
        motion: setting.motion
        disabled: !setting.canToggle
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
            KeyHint {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                shortcut: setting.toggleShortcut
                compact: true
                runtime: setting.runtime
                theme: setting.theme
                emphasized: setting.active || setting.keyboardSelected
                emphasisColor: setting.roleAccent
            }
        }

        Row {
            width: parent.width
            height: 15
            spacing: setting.theme.spacing1
            Text {
                width: Math.max(1, parent.width - temperatureValue.implicitWidth - parent.spacing)
                text: setting.label
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: setting.theme.textStrong
                font.family: setting.runtime.fontMono
                font.pixelSize: setting.theme.fontSize(9)
                font.weight: setting.active ? Font.DemiBold : Font.Medium
            }
            Text {
                id: temperatureValue
                text: setting.valueText
                color: setting.active ? setting.roleAccent : setting.theme.textMuted
                font.family: setting.runtime.fontMono
                font.pixelSize: setting.theme.fontSize(9)
                font.weight: Font.DemiBold
            }
        }

        Row {
            width: parent.width
            height: 19
            spacing: setting.theme.spacing1

            ShellSlider {
                width: Math.max(1, parent.width - (adjustHint.visible ? adjustHint.implicitWidth + parent.spacing : 0))
                height: parent.height
                theme: setting.theme
                motion: setting.motion
                from: setting.from
                to: setting.to
                value: setting.value
                enabled: setting.canAdjust
                trackHeight: 6
                handleSize: 16
                accentColor: setting.roleAccent
                Accessible.role: Accessible.Slider
                Accessible.name: setting.label + " " + setting.valueText
                onInteractionStarted: setting.sliderActivated()
                onValueRequested: next => setting.valueRequested(next)
            }

            // Adjustment appears next to the parameter, never in place of
            // the primary action's persistent shortcut in the tile header.
            KeyHint {
                id: adjustHint
                visible: setting.keyboardSelected
                anchors.verticalCenter: parent.verticalCenter
                shortcut: "H/L"
                compact: true
                runtime: setting.runtime
                theme: setting.theme
                emphasized: true
                emphasisColor: setting.roleAccent
            }
        }
    }
}
