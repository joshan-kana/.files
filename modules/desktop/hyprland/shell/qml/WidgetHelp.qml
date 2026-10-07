import QtQuick

Item {
    id: help

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

    property bool open: false
    property string title: "Controls"
    property var bindings: []

    signal dismissed

    z: 200
    visible: opacity > 0.01
    opacity: open ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: motion.fast
            easing.type: help.open ? motion.enterType : motion.exitType
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.68)

        MouseArea {
            anchors.fill: parent
            enabled: help.open
            onClicked: {
                help.open = false;
                help.dismissed();
            }
        }
    }

    SquircleSurface {
        id: helpCard

        width: Math.min(parent.width - theme.spacing5 * 2, 430)
        height: Math.min(parent.height - theme.spacing5 * 2, Math.max(180, content.implicitHeight + theme.spacing5 * 2))
        anchors.centerIn: parent

        exponent: theme.squircleExponent
        cornerRadius: theme.radiusLarge
        fillColor: theme.panelFill
        borderColor: theme.subtleBorder
        borderWidth: theme.borderThin

        MouseArea {
            anchors.fill: parent
            onClicked: mouse => mouse.accepted = true
        }

        Column {
            id: content

            anchors {
                fill: parent
                margins: theme.spacing5
            }
            spacing: theme.spacing3

            Text {
                width: parent.width
                text: help.title
                color: theme.textStrong
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(19)
                font.weight: Font.DemiBold
            }

            Rectangle {
                width: parent.width
                height: 1
                color: theme.subtleBorder
            }

            Repeater {
                model: help.bindings

                delegate: Row {
                    required property var modelData

                    width: content.width
                    spacing: theme.spacing3

                    SquircleSurface {
                        width: Math.max(64, Math.min(132, keyLabel.implicitWidth + theme.spacing4))
                        height: 30
                        exponent: theme.squircleExponent
                        cornerRadius: theme.radiusSmall
                        fillColor: theme.focusFill
                        borderColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28)
                        borderWidth: theme.borderThin

                        Text {
                            id: keyLabel
                            anchors.centerIn: parent
                            text: modelData.key
                            color: theme.accent
                            font.family: runtime.fontMono
                            font.pixelSize: theme.fontSize(10)
                            font.weight: Font.DemiBold
                        }
                    }

                    Text {
                        width: parent.width - parent.children[0].width - parent.spacing
                        anchors.verticalCenter: parent.children[0].verticalCenter
                        text: modelData.action
                        color: theme.text
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(12)
                        elide: Text.ElideRight
                    }
                }
            }

            Text {
                width: parent.width
                text: "? or Esc to return"
                horizontalAlignment: Text.AlignRight
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(10)
            }
        }
    }
}
