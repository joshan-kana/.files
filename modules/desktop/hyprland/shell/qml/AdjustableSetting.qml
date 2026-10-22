pragma ComponentBehavior: Bound
import QtQuick

// One compact Visual Modes tile owns the toggle, value and bounded adjustments.
// State and actions still come from the caller's canonical service owner.
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

    height: 78
    surfaceLayer: ShellSurface.Control
    cornerRadius: active ? theme.radiusLarge : theme.radiusMedium
    outlined: active
    luminous: active
    luminousColor: roleAccent
    borderColor: active ? roleAccent : "transparent"
    fillColor: active ? theme.blend(theme.controlBase, roleAccent, theme.dark ? 0.12 : 0.08) : theme.expressiveSurfaceStrong

    Column {
        anchors {
            fill: parent
            margins: setting.theme.spacing2
        }
        spacing: setting.theme.spacing1
        Row {
            width: parent.width
            height: 30
            spacing: setting.theme.spacing1
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: setting.icon
                font.family: "Symbols Nerd Font"
                font.pixelSize: setting.theme.fontSize(16)
                color: setting.roleAccent
            }
            Text {
                width: Math.max(1, parent.width - toggleAction.width - 35)
                anchors.verticalCenter: parent.verticalCenter
                text: setting.label
                color: setting.theme.textStrong
                font.family: setting.runtime.fontMono
                font.pixelSize: setting.theme.fontSize(10)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            ShellAction {
                id: toggleAction
                width: 66
                height: 30
                anchors.verticalCenter: parent.verticalCenter
                runtime: setting.runtime
                theme: setting.theme
                motion: setting.motion
                compact: true
                horizontalCompact: true
                title: setting.active ? "ON" : "OFF"
                shortcut: setting.toggleShortcut
                active: setting.active
                enabled: setting.canToggle
                onActivated: setting.toggleRequested()
            }
        }
        Row {
            width: parent.width
            height: 29
            spacing: setting.theme.spacing1
            ShellAction {
                id: decreaseAction
                width: 49
                height: 29
                runtime: setting.runtime
                theme: setting.theme
                motion: setting.motion
                compact: true
                horizontalCompact: true
                title: "−"
                enabled: setting.canDecrease
                onActivated: setting.decreaseRequested()
            }
            Text {
                width: Math.max(1, parent.width - decreaseAction.width - increaseAction.width - parent.spacing * 2)
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: setting.valueText
                color: setting.theme.textStrong
                font.family: setting.runtime.fontMono
                font.pixelSize: setting.theme.fontSize(10)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            ShellAction {
                id: increaseAction
                width: 49
                height: 29
                runtime: setting.runtime
                theme: setting.theme
                motion: setting.motion
                compact: true
                horizontalCompact: true
                title: "+"
                enabled: setting.canIncrease
                onActivated: setting.increaseRequested()
            }
        }
    }
}
