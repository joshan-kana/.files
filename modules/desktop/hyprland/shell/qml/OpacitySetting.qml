pragma ComponentBehavior: Bound
import QtQuick

// A Visual Modes tile with the same surface, hover and keycap treatment as
// QuickSettingChip. The slider adjusts actual opacity without toggling the tile.
ShellSurface {
    id: setting

    required property RuntimeConfig runtime
    required property string label
    required property real opacityValue
    property real minimumValue: 0.20
    property real maximumValue: 1
    property string valueUnit: "opacity"
    property string icon: ""
    property string shortcut: ""
    property bool active: false
    property bool keyboardSelected: false
    property bool blurAdjustable: false
    property bool blurEditing: false
    property int blurValue: 15
    signal blurActivated
    signal blurRequested(real value)
    signal sliderActivated
    property color roleAccent: theme.accent

    signal toggleRequested
    signal opacityRequested(real value)

    height: 78
    Accessible.role: Accessible.Button
    Accessible.name: label + ", " + Math.round(opacityValue * 100) + "% " + valueUnit + (blurAdjustable ? ", blur " + blurValue + " pixels" : "")

    // Scale inward at rest and fill the allocated bounds on hover.
    // The hub viewport clips content outside its edge during panel morphs.
    scale: toggleArea.pressed ? 0.94 : tileHover.hovered ? 1 : 0.982
    Behavior on scale {
        Anim {
            motion: setting.motion
            type: Anim.FastSpatial
        }
    }

    surfaceLayer: ShellSurface.Control
    cornerRadius: active ? theme.radiusLarge : theme.radiusMedium
    // An enabled setting keeps the same accent outline as other Controls
    // tiles. Keyboard selection adds a stronger focus border independently.
    outlined: active || keyboardSelected
    luminous: active || keyboardSelected
    luminousColor: roleAccent
    borderWidth: keyboardSelected ? theme.borderFocus : active ? theme.borderThin : 0
    borderColor: keyboardSelected ? theme.blend(roleAccent, theme.textStrong, 0.55) : active ? roleAccent : "transparent"
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
                width: Math.max(1, parent.width - opacityValueButton.width - blurValueButton.width - parent.spacing * (setting.blurAdjustable ? 2 : 1))
                text: setting.label
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: setting.theme.textStrong
                font.family: setting.runtime.fontSans
                font.pixelSize: setting.theme.fontSize(9)
                font.weight: setting.active ? Font.DemiBold : Font.Medium
            }

            Item {
                id: opacityValueButton
                width: opacityValueLabel.implicitWidth + (setting.blurAdjustable ? setting.theme.spacing2 : 0)
                height: parent.height
                Text {
                    id: opacityValueLabel
                    anchors.centerIn: parent
                    text: Math.round(setting.opacityValue * 100) + "%"
                    color: setting.active && !setting.blurEditing ? setting.roleAccent : setting.theme.textMuted
                    font.family: setting.runtime.fontSans
                    font.pixelSize: setting.theme.fontSize(9)
                    font.weight: Font.DemiBold
                }
                StateLayer {
                    visible: setting.blurAdjustable
                    theme: setting.theme
                    motion: setting.motion
                    cornerRadius: setting.theme.radiusSmall
                    Accessible.role: Accessible.Button
                    Accessible.name: "Adjust frosted-glass opacity"
                    onActivated: setting.sliderActivated()
                }
            }

            Item {
                id: blurValueButton
                visible: setting.blurAdjustable
                width: visible ? blurValueLabel.implicitWidth + setting.theme.spacing2 : 0
                height: parent.height
                Text {
                    id: blurValueLabel
                    anchors.centerIn: parent
                    text: "Blur " + setting.blurValue
                    color: setting.blurEditing ? setting.roleAccent : setting.theme.textMuted
                    font.family: setting.runtime.fontSans
                    font.pixelSize: setting.theme.fontSize(9)
                    font.weight: Font.DemiBold
                }
                StateLayer {
                    theme: setting.theme
                    motion: setting.motion
                    cornerRadius: setting.theme.radiusSmall
                    Accessible.role: Accessible.Button
                    Accessible.name: "Adjust frosted-glass blur softness"
                    onActivated: setting.blurActivated()
                }
            }
        }

        ShellSlider {
            width: parent.width
            height: 19
            theme: setting.theme
            motion: setting.motion
            from: setting.blurEditing ? 5 : setting.minimumValue
            to: setting.blurEditing ? 25 : setting.maximumValue
            value: setting.blurEditing ? setting.blurValue : setting.opacityValue
            trackHeight: 6
            handleSize: 16
            accentColor: setting.roleAccent
            onInteractionStarted: {
                if (setting.blurEditing)
                    setting.blurActivated();
                else
                    setting.sliderActivated();
            }
            onValueRequested: next => {
                if (setting.blurEditing)
                    setting.blurRequested(next);
                else
                    setting.opacityRequested(next);
            }
        }
    }

    // Keep the keycap aligned to the tile, independently of icon and slider layout.
    TileKeyHint {
        visible: setting.shortcut.length > 0 || setting.keyboardSelected
        shortcut: setting.keyboardSelected ? setting.runtime.shellHint("OpacitySetting.level") : setting.shortcut
        compact: true
        runtime: setting.runtime
        motion: setting.motion
        theme: setting.theme
        emphasized: setting.active || setting.keyboardSelected
        emphasisColor: setting.roleAccent
    }
}
