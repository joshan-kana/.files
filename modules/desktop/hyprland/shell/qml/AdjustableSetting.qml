pragma ComponentBehavior: Bound
import QtQuick

// A QuickSettingChip-sized toggle with separate bounded adjustment actions.
// The tile toggles everywhere except its two adjustment buttons.
ShellSurface {
    id: setting
    required property RuntimeConfig runtime
    required property string label
    required property string valueText
    property string icon: ""
    property string toggleShortcut: ""
    property string decrementShortcut: ""
    property string incrementShortcut: ""
    property bool active: false
    property bool canToggle: true
    property bool canDecrease: true
    property bool canIncrease: true
    property color roleAccent: theme.accent
    signal toggleRequested
    signal decreaseRequested
    signal increaseRequested

    height: 104
    Accessible.role: Accessible.Button
    Accessible.name: label + ", " + valueText + (active ? ", on" : ", off")

    surfaceLayer: ShellSurface.Control
    cornerRadius: active ? theme.radiusLarge : theme.radiusMedium
    outlined: active
    luminous: active
    luminousColor: roleAccent
    borderColor: active ? roleAccent : "transparent"
    hovered: toggleArea.containsMouse
    fillColor: active ? theme.blend(theme.materialContainerHigh, roleAccent, theme.dark ? 0.28 : 0.21) : theme.materialContainer
    Behavior on cornerRadius {
        Anim {
            motion: setting.motion
            type: Anim.FastSpatial
        }
    }

    // Behind the content, so the independent −/+ buttons consume their own
    // pointer events and cannot accidentally toggle Night Light.
    StateLayer {
        id: toggleArea
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
            topMargin: setting.theme.spacing3
            bottomMargin: setting.theme.spacing2
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
                font.pixelSize: setting.theme.fontSize(20)
            }
            KeyHint {
                visible: setting.toggleShortcut.length > 0
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                shortcut: setting.toggleShortcut
                compact: true
                runtime: setting.runtime
                theme: setting.theme
                emphasized: setting.active
                emphasisColor: setting.roleAccent
            }
        }

        Row {
            width: parent.width
            height: 30
            spacing: setting.theme.spacing1
            ShellAction {
                id: decreaseButton
                width: 66
                height: parent.height
                runtime: setting.runtime
                theme: setting.theme
                motion: setting.motion
                compact: true
                iconOnly: true
                iconHint: true
                inlineIconHint: true
                shortcut: setting.decrementShortcut
                icon: "−"
                title: "Decrease temperature"
                // Keep the hit target active at its limit so the click never
                // falls through to the tile's toggle handler.
                opacity: setting.canDecrease ? 1 : 0.42
                onActivated: {
                    if (setting.canDecrease)
                        setting.decreaseRequested();
                }
            }
            Column {
                width: Math.max(1, parent.width - decreaseButton.width - increaseButton.width - parent.spacing * 2)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                    width: parent.width
                    text: setting.label
                    color: setting.theme.textStrong
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    font.family: setting.runtime.fontMono
                    font.pixelSize: setting.theme.fontSize(9)
                    font.weight: setting.active ? Font.DemiBold : Font.Medium
                }
                Text {
                    width: parent.width
                    text: setting.valueText
                    color: setting.theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    font.family: setting.runtime.fontMono
                    font.pixelSize: setting.theme.fontSize(9)
                }
            }
            ShellAction {
                id: increaseButton
                width: 66
                height: parent.height
                runtime: setting.runtime
                theme: setting.theme
                motion: setting.motion
                compact: true
                iconOnly: true
                iconHint: true
                inlineIconHint: true
                shortcut: setting.incrementShortcut
                icon: "+"
                title: "Increase temperature"
                opacity: setting.canIncrease ? 1 : 0.42
                onActivated: {
                    if (setting.canIncrease)
                        setting.increaseRequested();
                }
            }
        }
    }
}
