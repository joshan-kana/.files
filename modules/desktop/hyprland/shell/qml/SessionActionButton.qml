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
        fillColor: button.armed ? button.theme.warning : button.selected || pointer.containsMouse ? button.theme.accent : button.theme.layer2
        borderColor: button.armed ? button.theme.warning : button.selected ? button.theme.accent : button.theme.subtleBorder
        borderWidth: button.selected ? button.theme.borderFocus : button.theme.borderThin

        Behavior on cornerRadius {
            NumberAnimation {
                duration: button.motion.spatialFast
                easing.type: button.motion.spatialType
            }
        }
        Behavior on exponent {
            NumberAnimation {
                duration: button.motion.spatialFast
                easing.type: button.motion.spatialType
            }
        }

        SquircleSurface {
            id: ripple
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            cornerRadius: surface.cornerRadius
            exponent: surface.exponent
            fillColor: button.armed ? button.theme.background : button.theme.textStrong
            opacity: 0
            scale: 0.2

            SequentialAnimation {
                id: rippleMotion
                PropertyAction {
                    target: ripple
                    property: "opacity"
                    value: 0.16
                }
                PropertyAction {
                    target: ripple
                    property: "scale"
                    value: 0.25
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: ripple
                        property: "scale"
                        to: 1
                        duration: button.motion.spatialNormal
                        easing.type: button.motion.spatialType
                    }
                    NumberAnimation {
                        target: ripple
                        property: "opacity"
                        to: 0
                        duration: button.motion.effectsNormal
                        easing.type: button.motion.effectsType
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: button.icon
            color: button.armed ? button.theme.background : button.selected || pointer.containsMouse ? button.theme.background : button.theme.textStrong
            font.family: "Symbols Nerd Font"
            font.pixelSize: button.theme.fontSize(43)
            font.weight: Font.Normal
        }

        MouseArea {
            id: pointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: button.hovered()
            onPressed: {
                if (button.motion.enabled)
                    rippleMotion.restart();
            }
            onClicked: button.activated()
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
