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
    height: 50
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
        elevated: true
        outlined: true
        fillColor: theme.paneBase

        // One uninterrupted hover shape, shared by the two pointer targets.
        // Neither target draws its own partial-width highlight.
        StateLayer {
            theme: island.theme
            motion: island.motion
            cornerRadius: theme.radiusIsland
            stateColor: island.theme.textStrong
            acceptedButtons: Qt.NoButton
            hoverEnabled: false
            manualHover: mainHitArea.containsMouse || playbackHitArea.containsMouse
            manualPress: mainHitArea.pressed || playbackHitArea.pressed
        }

        Item {
            id: artwork

            width: 40
            height: 40
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
                color: island.theme.roleColor("media")
                font.family: island.runtime.fontMono
                font.pixelSize: island.theme.fontSize(19)
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

            MarqueeText {
                width: parent.width
                text: island.media.title
                color: island.theme.textStrong
                font.family: island.runtime.fontMono
                font.pixelSize: island.theme.fontSize(11)
                font.weight: Font.DemiBold
            }

            MarqueeText {
                width: parent.width
                text: island.media.artist
                color: island.theme.textMuted
                font.family: island.runtime.fontMono
                font.pixelSize: island.theme.fontSize(9)
            }
        }

        Item {
            id: miniSpectrum

            width: island.width >= 410 ? 148 : island.width >= 320 ? 75 : 0
            height: 37
            anchors {
                right: playbackZone.left
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

        Item {
            id: playbackZone
            width: 54
            height: parent.height
            anchors.right: parent.right

            ShellSurface {
                id: state
                width: 34
                height: 34
                anchors.centerIn: parent

                theme: island.theme
                motion: island.motion
                surfaceLayer: ShellSurface.Control
                selected: island.media.playing
                cornerRadius: theme.radiusSmall
                luminous: playbackHitArea.containsMouse && island.media.canTogglePlaying
                hovered: playbackHitArea.containsMouse
                lightIntensity: 0.8

                Text {
                    anchors.centerIn: parent
                    text: island.media.playing ? "󰏤" : "󰐊"
                    color: island.media.playing ? island.theme.roleColor("media") : island.theme.textMuted
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: island.theme.fontSize(17)
                }
            }

            // The entire right-hand zone is a play/pause target, including
            // the spacing around the inset button. No dead strip at the edge.
            MouseArea {
                id: playbackHitArea
                anchors.fill: parent
                Accessible.role: Accessible.Button
                Accessible.name: island.media.playing ? "Pause playback" : "Resume playback"
                enabled: island.media.canTogglePlaying
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: island.media.togglePlaying()
            }
        }

        MouseArea {
            id: mainHitArea
            Accessible.role: Accessible.Button
            Accessible.name: "Open Now Playing"
            anchors {
                left: parent.left
                right: playbackZone.left
                top: parent.top
                bottom: parent.bottom
            }
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: island.activated()
        }
    }
}
