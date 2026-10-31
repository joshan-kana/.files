pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: button

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property string icon: ""
    property string label: ""
    property bool selected: false
    property bool armed: false
    property color accentColor: theme.roleColor("resources")

    signal activated
    signal hovered

    implicitWidth: 154
    implicitHeight: 155

    // Port of end-4's large morphing session buttons. The existing squircle
    // owns the geometry; neither a second shape implementation nor a mask is needed.
    ShellSurface {
        id: surface
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
        }
        width: 122
        height: 122
        theme: button.theme
        motion: button.motion
        cornerRadius: button.selected ? width / 2 : button.theme.radiusLarge
        exponent: button.selected ? 2.2 : button.theme.squircleExponent
        fillColor: button.armed ? button.theme.blend(button.theme.materialPrimaryContainer, button.theme.warning, 0.25) : button.selected ? button.theme.blend(button.theme.materialContainerHigh, button.accentColor, button.theme.dark ? 0.34 : 0.27) : button.theme.materialContainer
        borderColor: button.armed ? button.theme.warning : button.selected ? button.accentColor : "transparent"
        borderWidth: button.selected || button.armed ? button.theme.borderFocus : 0

        Behavior on cornerRadius {
            NumberAnimation {
                duration: button.motion.spatialFast
                easing.type: button.motion.spatialType
                easing.bezierCurve: button.motion.spatialCurve
            }
        }
        Behavior on exponent {
            NumberAnimation {
                duration: button.motion.spatialFast
                easing.type: button.motion.spatialType
                easing.bezierCurve: button.motion.spatialCurve
            }
        }

        Text {
            anchors.centerIn: parent
            text: button.icon
            color: button.armed ? button.theme.warning : button.selected ? button.accentColor : button.theme.textStrong
            font.family: "Symbols Nerd Font"
            font.pixelSize: button.theme.fontSize(43)
            font.weight: Font.Normal
        }

        StateLayer {
            id: pointer
            theme: button.theme
            motion: button.motion
            selected: button.selected
            cornerRadius: surface.cornerRadius
            exponent: surface.exponent
            onEntered: button.hovered()
            onActivated: button.activated()
        }
    }

    Text {
        anchors {
            top: surface.bottom
            topMargin: button.theme.spacing2
            horizontalCenter: parent.horizontalCenter
        }
        text: button.armed ? "CONFIRM " + button.label.toUpperCase() : button.label
        color: button.armed ? button.theme.warning : button.selected ? button.accentColor : button.theme.textStrong
        font.family: button.runtime.fontMono
        font.pixelSize: button.theme.fontSize(11)
        font.weight: button.selected ? Font.DemiBold : Font.Medium
    }
}
