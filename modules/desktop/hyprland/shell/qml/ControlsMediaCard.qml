pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: card
    required property Theme theme
    required property Motion motion

    required property MediaState media
    required property SpectrumState spectrum
    required property RuntimeConfig runtime
    property bool active: false

    function pulseSeekAdjustment(): void {
        progressSlider.beginKeyboardAdjustment();
    }

    function triggerTransport(action: string, autoRepeat: bool): void {
        if (action === "back" || action === "forward")
            pulseSeekAdjustment();
        compactTransport.triggerAction(action, autoRepeat);
    }

    function triggerShuffle(): void {
        shuffleButton.trigger();
    }

    function triggerRepeat(): void {
        repeatButton.trigger();
    }

    function triggerOpen(): void {
        cardHit.trigger();
    }

    signal fullRequested

    SpectrumScale {
        id: spectrumScale
        lowHz: card.spectrum.lowHz
        highHz: card.spectrum.highHz
    }

    readonly property real heroSize: 64
    readonly property real visualizerWidth: width >= 520 ? Math.min(180, width * 0.27) : 0
    // Use theme geometry, not the child Column's implicitHeight: the hub
    // measures our own implicitHeight to choose the expansion size.
    readonly property real contentTopInset: Math.max(theme.spacing3, theme.spacing2 * 2 + theme.keycapHeight)
    readonly property real controlsHeight: heroSize + (media.available ? theme.spacing2 * 2 + Math.max(24, progressSlider.implicitHeight) + transportRow.implicitHeight : 0)
    implicitHeight: Math.max(media.available ? 178 : 152, controlsHeight + contentTopInset + theme.spacing3)
    StateLayer {
        id: cardHit
        growOnHover: true
        feedbackParent: visualBody
        theme: card.theme
        motion: card.motion
        stateColor: card.theme.roleColor("media")
        hoverOpacity: 0.08
        pressOpacity: 0.13
        cornerRadius: card.theme.radiusLarge
        Accessible.role: Accessible.Button
        Accessible.name: "Open Now Playing"
        Accessible.onPressAction: card.triggerOpen()
        onActivated: card.fullRequested()
    }

    Timer {
        interval: 1000
        repeat: true
        running: card.active && card.visible && card.media.playing
        onTriggered: card.media.refreshPosition()
    }

    Item {
        id: visualBody
        anchors.fill: parent
        scale: cardHit.defaultEffectScale
        ShellSurface {
            z: -1
            anchors.fill: parent
            theme: card.theme
            motion: card.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: card.theme.radiusLarge
            fillColor: card.media.available ? card.theme.blend(card.theme.groupBase, card.theme.roleColor("media"), card.theme.dark ? 0.075 : 0.045) : card.theme.groupBase
        }

        Column {
            z: 1
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: card.theme.spacing3
                rightMargin: card.theme.spacing3
                topMargin: card.contentTopInset
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
                        font.family: card.runtime.fontSans
                        font.pixelSize: card.theme.fontSize(10)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    MarqueeText {
                        width: parent.width
                        text: card.media.available ? card.media.title : "No active player"
                        color: card.theme.textStrong
                        font.family: card.runtime.fontSans
                        font.pixelSize: card.theme.fontSize(15)
                        font.weight: Font.DemiBold
                    }
                    MarqueeText {
                        width: parent.width
                        text: card.media.available ? card.media.artist : "No playback"
                        color: card.theme.textMuted
                        font.family: card.runtime.fontSans
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
                id: progressSlider
                width: parent.width
                height: card.media.available ? Math.max(24, implicitHeight) : 0
                visible: card.media.available
                theme: card.theme
                motion: card.motion
                value: card.media.length > 0 ? Math.max(0, Math.min(1, card.media.position / card.media.length)) : 0
                enabled: card.media.seekable && card.media.length > 0
                density: ShellSlider.Compact
                Accessible.role: Accessible.Slider
                Accessible.name: "Playback position"
                onInteractionFinished: fraction => card.media.seekTo(card.media.length * fraction)
            }

            Row {
                id: transportRow
                width: implicitWidth
                height: visible ? implicitHeight : 0
                visible: card.media.available
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: card.theme.spacing2

                ShellAction {
                    id: shuffleButton
                    width: Math.max(44, implicitWidth)
                    height: Math.max(46, implicitHeight)
                    anchors.verticalCenter: parent.verticalCenter
                    runtime: card.runtime
                    theme: card.theme
                    motion: card.motion
                    compact: true
                    iconOnly: true
                    iconHint: true
                    icon: "󰒝"
                    title: card.media.shuffled ? "Shuffle on" : "Shuffle off"
                    shortcut: card.runtime.shellHint("ControlsMediaCard.shuffle")
                    active: card.media.shuffled
                    activeColor: theme.toggleColor
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
                    width: Math.max(44, implicitWidth)
                    height: Math.max(46, implicitHeight)
                    anchors.verticalCenter: parent.verticalCenter
                    runtime: card.runtime
                    theme: card.theme
                    motion: card.motion
                    compact: true
                    iconOnly: true
                    iconHint: true
                    icon: card.media.repeatState === 1 ? "󰑘" : "󰑖"
                    title: "Repeat " + card.media.repeatLabel
                    shortcut: card.runtime.shellHint("ControlsMediaCard.repeat")
                    active: card.media.repeatState !== 0
                    activeColor: theme.toggleColor
                    enabled: card.media.repeatAvailable
                    onActivated: card.media.toggleRepeat()
                }
            }
        }

        TileKeyHint {
            id: openHint
            z: 1
            primary: false
            visible: shortcut.length > 0
            shortcut: card.runtime.shellHint("ControlsMediaCard.open")
            runtime: card.runtime
            theme: card.theme
            motion: card.motion
        }
    }
}
