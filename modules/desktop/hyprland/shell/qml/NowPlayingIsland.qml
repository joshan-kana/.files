import QtQuick

Item {
    id: island

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion
    required property QtObject media
    required property QtObject spectrum

    signal activated

    width: media.available ? 458 : 0
    height: 40
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

    SpectrumScale {
        id: spectrumScale
        lowHz: spectrum.lowHz
        highHz: spectrum.highHz
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: island.activated()
    }

    SquircleSurface {
        anchors.fill: parent

        exponent: theme.squircleExponent
        cornerRadius: theme.radiusMedium
        fillColor: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
        borderColor: theme.subtleBorder
        borderWidth: theme.borderThin

        Item {
            id: artwork

            width: 32
            height: 32
            anchors {
                left: parent.left
                leftMargin: 4
                verticalCenter: parent.verticalCenter
            }

            SquircleSurface {
                anchors.fill: parent
                exponent: theme.squircleExponent
                cornerRadius: theme.radiusSmall
                fillColor: theme.surfaceRaised
                borderColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20)
                borderWidth: theme.borderThin
            }

            Image {
                anchors.fill: parent
                anchors.margins: 1
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
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(14)
            }
        }

        Column {
            anchors {
                left: artwork.right
                right: miniSpectrum.left
                leftMargin: theme.spacing3
                rightMargin: theme.spacing3
                verticalCenter: parent.verticalCenter
            }
            spacing: 0

            Text {
                width: parent.width
                text: media.title
                color: theme.textStrong
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(11)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: media.artist
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(9)
                elide: Text.ElideRight
            }
        }

        Item {
            id: miniSpectrum

            width: 148
            height: 32
            anchors {
                right: state.left
                rightMargin: theme.spacing2
                verticalCenter: parent.verticalCenter
            }
            visible: media.playing
            opacity: media.playing && spectrum.connected ? 0.95 : 0

            SpectrumBars {
                anchors.fill: parent
                spectrum: island.spectrum
                theme: island.theme
                frequencyScale: spectrumScale
                barCount: 24
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: motion.fast
                }
            }
        }

        SquircleSurface {
            id: state

            width: 30
            height: 30
            anchors {
                right: parent.right
                rightMargin: 5
                verticalCenter: parent.verticalCenter
            }

            exponent: theme.squircleExponent
            cornerRadius: theme.radiusSmall
            fillColor: media.playing ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.16) : theme.surfaceRaised
            borderColor: "transparent"
            borderWidth: 0

            Text {
                anchors.centerIn: parent
                text: media.playing ? "Ⅱ" : "▶"
                color: media.playing ? theme.accent : theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(10)
                font.weight: Font.Bold
            }
        }
    }
}
