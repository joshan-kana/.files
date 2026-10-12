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
        width: 115
        height: 115
        theme: button.theme
        motion: button.motion
        cornerRadius: button.selected || pointer.containsMouse ? width / 2 : button.theme.radiusLarge
        exponent: button.selected || pointer.containsMouse ? 2.2 : button.theme.squircleExponent
        fillColor: button.armed ? button.theme.focusFill : button.selected ? button.theme.accent : button.theme.expressiveSurfaceStrong
        borderColor: button.armed ? button.theme.warning : button.selected ? button.theme.accent : "transparent"
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
            color: button.armed ? button.theme.warning : button.selected ? button.theme.background : button.theme.textStrong
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
        color: button.armed ? button.theme.warning : button.selected ? button.theme.accent : button.theme.textStrong
        font.family: button.runtime.fontMono
        font.pixelSize: button.theme.fontSize(11)
        font.weight: button.selected ? Font.DemiBold : Font.Medium
    }
}
