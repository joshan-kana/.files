pragma ComponentBehavior: Bound
import QtQuick

ShellSurface {
    id: card

    required property MediaState media
    required property SpectrumState spectrum
    required property RuntimeConfig runtime
    property bool active: false

    signal fullRequested

    SpectrumScale {
        id: spectrumScale
        lowHz: card.spectrum.lowHz
        highHz: card.spectrum.highHz
    }

    readonly property real heroSize: 64
    readonly property real visualizerWidth: width >= 520 ? Math.min(180, width * 0.27) : 0
    implicitHeight: media.available ? 178 : 152
    surfaceLayer: ShellSurface.Group
    cornerRadius: theme.radiusLarge
    fillColor: media.available ? theme.blend(theme.groupBase, theme.roleColor("media"), theme.dark ? 0.075 : 0.045) : theme.groupBase

    StateLayer {
        theme: card.theme
        motion: card.motion
        stateColor: card.theme.roleColor("media")
        hoverOpacity: 0.08
        pressOpacity: 0.13
        cornerRadius: card.theme.radiusLarge
        Accessible.role: Accessible.Button
        Accessible.name: "Open Now Playing"
        onActivated: card.fullRequested()
    }

    Timer {
        interval: 1000
        repeat: true
        running: card.active && card.visible && card.media.playing
        onTriggered: card.media.refreshPosition()
    }

    Column {
        anchors {
            fill: parent
            margins: card.theme.spacing3
        }
        spacing: card.theme.spacing2

        Row {
            width: parent.width
            height: card.heroSize
            spacing: card.theme.spacing3

            ShellSurface {
                width: card.heroSize
                height: card.heroSize
                theme: card.theme
                motion: card.motion
                surfaceLayer: ShellSurface.Control
                cornerRadius: card.theme.radiusMedium
                clip: true

                Image {
                    anchors.fill: parent
                    source: card.media.artUrl
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectCrop
                    visible: card.media.artUrl.length > 0
                }
                Text {
                    anchors.centerIn: parent
                    visible: card.media.artUrl.length === 0
                    text: "󰎆"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: card.theme.fontSize(27)
                    color: card.theme.roleColor("media")
                }
            }

            Column {
                width: Math.max(1, parent.width - card.heroSize - parent.spacing - (card.visualizerWidth > 0 ? card.visualizerWidth + parent.spacing : 0))
                anchors.verticalCenter: parent.verticalCenter
                spacing: card.theme.spacing1

                Text {
                    width: parent.width
                    text: card.media.available ? card.media.identity : "MEDIA"
                    color: card.theme.readableRoleColor("media")
                    font.family: card.runtime.fontMono
                    font.pixelSize: card.theme.fontSize(10)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                MarqueeText {
                    width: parent.width
                    text: card.media.available ? card.media.title : "No active player"
                    color: card.theme.textStrong
                    font.family: card.runtime.fontMono
                    font.pixelSize: card.theme.fontSize(15)
                    font.weight: Font.DemiBold
                }
                MarqueeText {
                    width: parent.width
                    text: card.media.available ? card.media.artist : "No playback"
                    color: card.theme.textMuted
                    font.family: card.runtime.fontMono
                    font.pixelSize: card.theme.fontSize(11)
                }
            }

            SpectrumBars {
                width: card.visualizerWidth
                height: 56
                anchors.verticalCenter: parent.verticalCenter
                visible: card.visualizerWidth > 0 && card.active && card.media.available
                enabled: visible
                spectrum: card.spectrum
                theme: card.theme
                frequencyScale: spectrumScale
                barCount: 24
            }
        }

        ShellSlider {
            width: parent.width
            height: card.media.available ? 24 : 0
            visible: card.media.available
            theme: card.theme
            motion: card.motion
            value: card.media.length > 0 ? Math.max(0, Math.min(1, card.media.position / card.media.length)) : 0
            enabled: card.media.seekable && card.media.length > 0
            accentColor: card.theme.roleColor("media")
            trackHeight: 7
            handleSize: 16
            Accessible.role: Accessible.Slider
            Accessible.name: "Playback position"
            onInteractionFinished: fraction => card.media.seekTo(card.media.length * fraction)
        }

        Row {
            width: implicitWidth
            height: visible ? 46 : 0
            visible: card.media.available
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: card.theme.spacing2

            ShellAction {
                id: shuffleButton
                width: 44
                height: 42
                anchors.verticalCenter: parent.verticalCenter
                runtime: card.runtime
                theme: card.theme
                motion: card.motion
                compact: true
                iconOnly: true
                iconHint: true
                icon: "󰒝"
                title: card.media.shuffled ? "Shuffle on" : "Shuffle off"
                shortcut: "Z"
                active: card.media.shuffled
                enabled: card.media.shuffleAvailable
                onActivated: card.media.toggleShuffle()
            }

            MediaTransport {
                id: compactTransport
                width: implicitWidth
                visible: card.media.available
                anchors.verticalCenter: parent.verticalCenter
                media: card.media
                runtime: card.runtime
                theme: card.theme
                motion: card.motion
                compact: true
                minimal: true
                simple: card.width < 490
            }

            ShellAction {
                id: repeatButton
                width: 44
                height: 42
                anchors.verticalCenter: parent.verticalCenter
                runtime: card.runtime
                theme: card.theme
                motion: card.motion
                compact: true
                iconOnly: true
                iconHint: true
                icon: card.media.repeatState === 1 ? "󰑘" : "󰑖"
                title: "Repeat " + card.media.repeatLabel
                shortcut: "B"
                active: card.media.repeatState !== 0
                enabled: card.media.repeatAvailable
                onActivated: card.media.toggleRepeat()
            }
        }
    }
}
