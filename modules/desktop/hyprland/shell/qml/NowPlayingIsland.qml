import QtQuick

Item {
    id: island

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property MediaState media
    required property SpectrumState spectrum

    signal activated

    // Leave the centered clock island unobstructed on narrow logical screens.
    property real maximumWidth: 458
    width: media.available && maximumWidth >= 165 ? Math.min(458, maximumWidth) : 0
    height: 40
    visible: width > 1
    opacity: media.available ? 1 : 0

    Behavior on width {
        // Layout reductions must follow monitor geometry immediately.
        enabled: island.maximumWidth >= 458
        NumberAnimation {
            duration: island.motion.normal
            easing.type: island.motion.enterType
            easing.bezierCurve: island.motion.enterCurve
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: island.motion.fast
            easing.type: island.motion.effectsType
            easing.bezierCurve: island.motion.effectsCurve
        }
    }

    SpectrumScale {
        id: spectrumScale
        lowHz: island.spectrum.lowHz
        highHz: island.spectrum.highHz
    }

    ShellSurface {
        anchors.fill: parent

        theme: island.theme
        motion: island.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusIsland
        exponent: Math.min(4, theme.squircleExponent)
        luminous: true
        luminousColor: theme.accent
        hovered: islandPress.containsMouse

        Item {
            id: artwork

            width: 32
            height: 32
            anchors {
                left: parent.left
                leftMargin: 4
                verticalCenter: parent.verticalCenter
            }

            ShellSurface {
                anchors.fill: parent
                theme: island.theme
                motion: island.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: theme.radiusSmall
                clip: true
            }

            Image {
                anchors.fill: parent
                anchors.margins: 0
                visible: island.media.artUrl.length > 0
                source: island.media.artUrl
                sourceSize.width: 56
                sourceSize.height: 56
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }

            Text {
                anchors.centerIn: parent
                visible: island.media.artUrl.length === 0
                text: "♫"
                color: island.theme.accent
                font.family: island.runtime.fontMono
                font.pixelSize: island.theme.fontSize(14)
            }
        }

        Column {
            anchors {
                left: artwork.right
                right: miniSpectrum.left
                leftMargin: island.theme.spacing3
                rightMargin: island.theme.spacing3
                verticalCenter: parent.verticalCenter
            }
            spacing: 0

            Text {
                width: parent.width
                text: island.media.title
                color: island.theme.textStrong
                font.family: island.runtime.fontMono
                font.pixelSize: island.theme.fontSize(11)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: island.media.artist
                color: island.theme.textMuted
                font.family: island.runtime.fontMono
                font.pixelSize: island.theme.fontSize(9)
                elide: Text.ElideRight
            }
        }

        Item {
            id: miniSpectrum

            width: island.width >= 410 ? 148 : island.width >= 320 ? 75 : 0
            height: 32
            anchors {
                right: state.left
                rightMargin: island.theme.spacing2
                verticalCenter: parent.verticalCenter
            }
            visible: width > 0 && (island.media.playing || island.spectrum.hasEnergy)
            opacity: island.media.playing || island.spectrum.hasEnergy ? 0.95 : 0

            SpectrumBars {
                anchors.fill: parent
                spectrum: island.spectrum
                theme: island.theme
                frequencyScale: spectrumScale
                barCount: 24
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: island.motion.fast
                    easing.type: island.motion.effectsType
                    easing.bezierCurve: island.motion.effectsCurve
                }
            }
        }

        ShellSurface {
            id: state

            width: 30
            height: 30
            anchors {
                right: parent.right
                rightMargin: 5
                verticalCenter: parent.verticalCenter
            }

            theme: island.theme
            motion: island.motion
            surfaceLayer: ShellSurface.Control
            selected: island.media.playing
            cornerRadius: theme.radiusSmall

            Text {
                anchors.centerIn: parent
                text: island.media.playing ? "Ⅱ" : "▶"
                color: island.media.playing ? island.theme.accent : island.theme.textMuted
                font.family: island.runtime.fontMono
                font.pixelSize: island.theme.fontSize(10)
                font.weight: Font.Bold
            }
        }

        StateLayer {
            id: islandPress
            theme: island.theme
            motion: island.motion
            cornerRadius: theme.radiusIsland
            onActivated: island.activated()
        }
    }
}
