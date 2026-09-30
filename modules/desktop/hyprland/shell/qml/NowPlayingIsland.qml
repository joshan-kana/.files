import QtQuick

Item {
    id: island

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion
    required property QtObject media

    signal activated()

    width: media.available ? 390 : 0
    height: 44
    visible: width > 1
    opacity: media.available ? 1 : 0

    Behavior on width {
        NumberAnimation {
            duration: motion.normal
            easing.type: motion.enterType
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: motion.fast
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: island.activated()
    }

    SquircleSurface {
        anchors.fill: parent

        exponent: theme.squircleExponent
        cornerRadius: theme.radiusMedium
        fillColor: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.94)
        borderColor: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.76)
        borderWidth: theme.borderThin

        Item {
            id: artwork

            width: 32
            height: 32
            anchors {
                left: parent.left
                leftMargin: 7
                verticalCenter: parent.verticalCenter
            }

            SquircleSurface {
                anchors.fill: parent
                exponent: theme.squircleExponent
                cornerRadius: 9
                fillColor: theme.surfaceRaised
                borderColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28)
                borderWidth: theme.borderThin
            }

            Image {
                anchors {
                    fill: parent
                    margins: 2
                }

                visible: media.artUrl.length > 0
                source: media.artUrl
                sourceSize.width: 56
                sourceSize.height: 56
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }

            Text {
                anchors.centerIn: parent
                visible: media.artUrl.length === 0
                text: "♫"
                color: theme.accent
                font.family: runtime.fontSans
                font.pixelSize: 15
            }
        }

        Column {
            anchors {
                left: artwork.right
                right: state.left
                leftMargin: theme.spacing3
                rightMargin: theme.spacing3
                verticalCenter: parent.verticalCenter
            }
            spacing: 1

            Text {
                width: parent.width
                text: media.title
                color: theme.textStrong
                font.family: runtime.fontSans
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: media.artist
                color: theme.textMuted
                font.family: runtime.fontSans
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        Row {
            id: state
            anchors {
                right: parent.right
                rightMargin: theme.spacing3
                verticalCenter: parent.verticalCenter
            }
            spacing: 7

            Text {
                text: media.playing ? "LIVE" : "HOLD"
                color: media.playing ? theme.positive : theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 7
                radius: 3.5
                color: media.playing ? theme.positive : theme.outline

                SequentialAnimation on opacity {
                    running: media.playing && motion.enabled
                    loops: Animation.Infinite

                    NumberAnimation {
                        to: 0.38
                        duration: 520
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        to: 1
                        duration: 520
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }
}
