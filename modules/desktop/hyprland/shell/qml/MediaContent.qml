pragma ComponentBehavior: Bound
import QtQuick
import "DesktopIcons.js" as DesktopIcons

FocusScope {
    id: content

    required property MediaState media
    required property SpectrumState spectrum
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property AppearancePreferences appearance

    property bool engaged: false
    property bool returnToControls: false
    property bool helpOpen: false
    readonly property string visualizerMode: appearance.mediaVisualizerMode
    readonly property bool lyricsVisible: appearance.mediaLyricsVisible
    property bool scrubbing: false
    property real scrubFraction: 0
    readonly property var helpBindings: [
        {
            key: content.runtime.shellHint("MediaTransport.play"),
            action: media.playing ? "Pause playback" : "Play"
        },
        {
            key: [content.runtime.shellHint("MediaTransport.back"), content.runtime.shellHint("MediaTransport.forward")].join(" / ") + " · " + [content.runtime.shellHint("MediaTransport.backArrow"), content.runtime.shellHint("MediaTransport.forwardArrow")].join(" / "),
            action: "Seek " + media.seekSeconds + " seconds"
        },
        {
            key: [content.runtime.shellHint("MediaContent.shorter"), content.runtime.shellHint("MediaContent.longer")].join(" / "),
            action: "Seek interval · " + media.seekSeconds + "s"
        },
        {
            key: [content.runtime.shellHint("MediaTransport.previous"), content.runtime.shellHint("MediaTransport.next")].join(" / "),
            action: "Previous / next track"
        },
        {
            key: content.runtime.shellHint("MediaContent.visualizer"),
            action: "Switch visualizer"
        },
        {
            key: content.runtime.shellHint("MediaContent.lyrics"),
            action: "Overlay local synchronised lyrics (.lrc)"
        },
        {
            key: content.runtime.shellHint("MediaContent.shuffle"),
            action: media.shuffleAvailable ? "Toggle shuffle" : "Shuffle unsupported by player"
        },
        {
            key: content.runtime.shellHint("MediaContent.repeat"),
            action: media.repeatAvailable ? "Cycle repeat Off / All / One" : "Repeat unsupported by player"
        },
        {
            key: content.runtime.shellHint("MediaContent.player"),
            action: "Cycle connected media players"
        },
        ...(media.canRaise ? [
                {
                    key: content.runtime.shellHint("MediaContent.raise"),
                    action: "Open current media player"
                }
            ] : []), ...(media.rateAvailable ? [
                {
                    key: [content.runtime.shellHint("MediaContent.rateDown"), content.runtime.shellHint("MediaContent.rateUp")].join(" / "),
                    action: "Adjust selected player's playback speed"
                }
            ] : []),
        {
            key: content.runtime.shellHint("MediaContent.close"),
            action: content.returnToControls ? "Back to Controls" : "Close now playing"
        }
    ]

    signal helpScrollRequested(int steps)
    signal closeRequested

    implicitWidth: 920
    // Keep every action reachable without paging away from its controls on
    // 768p/compact screens; larger viewports retain the immersive spectrum.
    readonly property bool compactHeight: height < 760
    implicitHeight: compactHeight ? 640 : 720
    focus: engaged

    onEngagedChanged: {
        if (engaged) {
            forceActiveFocus();
            Qt.callLater(() => {
                if (content.engaged)
                    content.forceActiveFocus();
            });
        } else {
            content.motion.endKeyboardAdjustment();
            helpOpen = false;
            scrubbing = false;
        }
    }

    SpectrumScale {
        id: spectrumScale
        lowHz: content.spectrum.lowHz
        highHz: content.spectrum.highHz
    }

    Timer {
        interval: 250
        repeat: true
        running: content.engaged && content.media.playing && content.media.available
        onTriggered: content.media.refreshPosition()
    }

    function toggleVisualizer(): void {
        appearance.toggleMediaVisualizer();
    }

    function navigateBack(): void {
        if (helpOpen)
            helpOpen = false;
        else
            closeRequested();
    }

    function toggleLyrics(): void {
        appearance.toggleMediaLyrics();
    }

    function displayedPosition(): real {
        if (scrubbing && media.length > 0)
            return media.length * scrubFraction;
        return media.position;
    }

    function formatTime(seconds: real): string {
        if (!isFinite(seconds) || seconds < 0)
            return "--:--";
        const whole = Math.floor(seconds);
        const minutes = Math.floor(whole / 60);
        const remainder = whole % 60;
        return minutes + ":" + String(remainder).padStart(2, "0");
    }

    Item {
        anchors.fill: parent

        ShellSurface {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            // Album information and the visualiser are one media canvas.
            // Keep its geometry behind both sections rather than stacking
            // separately coloured, rounded cards.
            height: spectrumSlot.y + spectrumSlot.height + content.theme.spacing4
            theme: content.theme
            motion: content.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: content.theme.radiusLarge
            luminous: true
            luminousColor: content.theme.roleColor("media")
            fillColor: content.theme.surface
        }

        Row {
            id: header
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            anchors {
                topMargin: content.theme.spacing4
                leftMargin: content.theme.spacing4
                rightMargin: content.theme.spacing4
            }
            spacing: content.theme.spacing4

            ShellSurface {
                width: content.compactHeight ? 120 : 168
                height: width
                theme: content.theme
                motion: content.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: theme.radiusLarge
                clipContentToShape: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 0
                    source: content.media.artUrl
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectCrop
                    visible: content.media.artUrl.length > 0
                }

                Text {
                    anchors.centerIn: parent
                    visible: content.media.artUrl.length === 0
                    text: "♫"
                    color: content.theme.roleColor("media")
                    font.family: content.runtime.fontSans
                    font.pixelSize: content.theme.fontSize(48)
                }
            }

            Column {
                width: header.width - (content.compactHeight ? 120 : 168) - header.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: content.theme.spacing2

                Row {
                    width: parent.width
                    spacing: content.theme.spacing2
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(1, parent.width - resetPreferredAction.width - parent.spacing - (raiseAction.visible ? raiseAction.width + parent.spacing : 0))
                        text: content.media.available ? "Now playing" : "Media"
                        color: content.theme.readableRoleColor("media")
                        font.family: content.runtime.fontSans
                        font.pixelSize: content.theme.fontSize(12)
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                    ShellAction {
                        id: raiseAction
                        visible: content.media.canRaise
                        enabled: visible
                        width: implicitWidth
                        height: implicitHeight
                        runtime: content.runtime
                        theme: content.theme
                        motion: content.motion
                        compact: true
                        horizontalCompact: true
                        title: "Open player"
                        shortcut: content.runtime.shellHint("MediaContent.raise")
                        onActivated: {
                            content.media.raisePlayer();
                            content.closeRequested();
                        }
                    }
                    ShellUtilityAction {
                        id: resetPreferredAction
                        width: implicitWidth
                        runtime: content.runtime
                        theme: content.theme
                        motion: content.motion
                        title: "Restore default player"
                        icon: DesktopIcons.actionGlyph("reset")
                        shortcut: content.runtime.shellHint("MediaContent.preferReset")
                        onActivated: content.media.resetPreferredPlayer()
                    }
                }

                MarqueeText {
                    width: parent.width
                    text: content.media.title
                    color: content.theme.textStrong
                    font.family: content.runtime.fontSans
                    font.pixelSize: content.theme.fontSize(content.compactHeight ? 22 : 28)
                    font.weight: Font.DemiBold
                }

                MarqueeText {
                    width: parent.width
                    text: content.media.artist || content.media.identity || "No MPRIS player connected"
                    color: content.theme.textMuted
                    font.family: content.runtime.fontSans
                    font.pixelSize: content.theme.fontSize(13)
                }

                MarqueeText {
                    width: parent.width
                    visible: content.media.album.length > 0
                    text: content.media.album
                    color: content.theme.textMuted
                    opacity: 0.72
                    font.family: content.runtime.fontSans
                    font.pixelSize: content.theme.fontSize(10)
                }
            }
        }

        Column {
            id: spectrumSlot
            anchors {
                top: header.bottom
                left: parent.left
                right: parent.right
                topMargin: content.compactHeight ? content.theme.spacing3 : content.theme.spacing5
            }
            spacing: 0

            Item {
                // Spectrum and synced lyrics share the media canvas. Lyrics
                // layer over the active spectrum instead of replacing it.
                width: parent.width
                // Let the spectrum use the area between artwork and the
                // controls. The mode buttons now follow playback directly,
                // so unused bottom padding becomes visualiser height.
                height: Math.max(115, content.height - header.y - header.height - spectrumSlot.anchors.topMargin - transport.anchors.topMargin - transport.implicitHeight - mediaActions.anchors.topMargin - mediaActions.implicitHeight - content.theme.spacing3)
                clip: true

                SpectrumCurve {
                    anchors {
                        top: parent.top
                        right: parent.right
                        bottom: frequencyLabels.top
                        left: parent.left
                        topMargin: theme.spacing3
                        rightMargin: theme.spacing3
                        leftMargin: theme.spacing3
                    }

                    visible: content.visualizerMode === "curve" || opacity > 0.01
                    opacity: content.visualizerMode === "curve" ? 1 : 0

                    spectrum: content.spectrum
                    theme: content.theme
                    frequencyScale: spectrumScale

                    Behavior on opacity {
                        NumberAnimation {
                            duration: content.scrubbing ? 0 : content.motion.fast
                            easing.type: content.motion.enterType
                            easing.bezierCurve: content.motion.enterCurve
                        }
                    }
                }

                SpectrumBars {
                    anchors {
                        top: parent.top
                        right: parent.right
                        bottom: frequencyLabels.top
                        left: parent.left
                        topMargin: theme.spacing3
                        rightMargin: theme.spacing3
                        leftMargin: theme.spacing3
                    }

                    visible: content.visualizerMode === "bars" || opacity > 0.01
                    opacity: content.visualizerMode === "bars" ? 1 : 0

                    spectrum: content.spectrum
                    theme: content.theme
                    frequencyScale: spectrumScale

                    Behavior on opacity {
                        NumberAnimation {
                            duration: content.motion.fast
                            easing.type: content.motion.enterType
                            easing.bezierCurve: content.motion.enterCurve
                        }
                    }
                }

                MediaLyrics {
                    anchors.fill: parent
                    media: content.media
                    runtime: content.runtime
                    theme: content.theme
                    motion: content.motion
                    active: content.engaged && content.lyricsVisible
                    visible: content.lyricsVisible || opacity > 0.01
                    opacity: content.lyricsVisible ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: content.motion.contentFade
                            easing.type: content.motion.enterType
                            easing.bezierCurve: content.motion.enterCurve
                        }
                    }
                }

                Item {
                    id: frequencyLabels

                    height: 18
                    visible: true
                    z: 1
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        left: parent.left
                        rightMargin: content.theme.spacing3
                        bottomMargin: content.theme.spacing1
                        leftMargin: content.theme.spacing3
                    }

                    Repeater {
                        model: [
                            {
                                label: "20",
                                hz: 20
                            },
                            {
                                label: "60",
                                hz: 60
                            },
                            {
                                label: "250",
                                hz: 250
                            },
                            {
                                label: "1K",
                                hz: 1000
                            },
                            {
                                label: "4K",
                                hz: 4000
                            },
                            {
                                label: "20K",
                                hz: 20000
                            }
                        ]

                        delegate: Text {
                            required property var modelData

                            x: Math.max(0, Math.min(frequencyLabels.width - implicitWidth, spectrumScale.fromFrequency(modelData.hz) * frequencyLabels.width - implicitWidth / 2))
                            text: modelData.label
                            color: content.theme.textMuted
                            opacity: 0.62
                            font.family: content.runtime.fontSans
                            font.pixelSize: content.theme.fontSize(8)
                        }
                    }
                }
            }
        }

        Column {
            id: transport
            anchors {
                top: spectrumSlot.bottom
                left: parent.left
                right: parent.right
                topMargin: content.compactHeight ? content.theme.spacing3 : content.theme.spacing5
            }
            spacing: content.compactHeight ? content.theme.spacing2 : content.theme.spacing3

            ShellSlider {
                id: progressTrack

                width: parent.width
                theme: content.theme
                motion: content.motion
                from: 0
                to: 1
                value: {
                    if (!content.media.available || content.media.length <= 0)
                        return 0;
                    return content.scrubbing ? content.scrubFraction : Math.max(0, Math.min(1, content.media.position / content.media.length));
                }
                enabled: content.media.seekable && content.media.length > 0
                density: ShellSlider.Compact

                onInteractionStarted: value => {
                    content.scrubbing = true;
                    content.scrubFraction = value;
                }
                onInteractionUpdated: value => content.scrubFraction = value
                onInteractionFinished: value => {
                    content.scrubFraction = value;
                    const target = content.media.length * value;
                    content.scrubbing = false;
                    content.media.seekTo(target);
                }
                onInteractionCanceled: content.scrubbing = false
            }

            Row {
                width: parent.width

                Text {
                    text: content.formatTime(content.displayedPosition())
                    color: content.theme.textMuted
                    font.family: content.runtime.fontMono
                    font.pixelSize: content.theme.fontSize(10)
                }

                Item {
                    width: parent.width - parent.children[0].width - parent.children[2].width
                    height: 1
                }

                Text {
                    text: content.formatTime(content.media.length)
                    color: content.theme.textMuted
                    font.family: content.runtime.fontMono
                    font.pixelSize: content.theme.fontSize(10)
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: content.theme.spacing2

                ShellAction {
                    id: shuffleAction
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(58, implicitWidth)
                    height: Math.max(46, implicitHeight)
                    runtime: content.runtime
                    theme: content.theme
                    motion: content.motion
                    compact: true
                    iconOnly: true
                    iconHint: true
                    icon: "󰒝"
                    title: content.media.shuffled ? "Shuffle on" : "Shuffle off"
                    shortcut: content.runtime.shellHint("MediaContent.shuffle")
                    active: content.media.shuffled
                    activeColor: theme.toggleColor
                    enabled: content.media.shuffleAvailable
                    onActivated: content.media.toggleShuffle()
                }

                ShellAction {
                    id: repeatAction
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(58, implicitWidth)
                    height: Math.max(46, implicitHeight)
                    runtime: content.runtime
                    theme: content.theme
                    motion: content.motion
                    compact: true
                    iconOnly: true
                    iconHint: true
                    icon: content.media.repeatState === 1 ? "󰑘" : "󰑖"
                    title: "Repeat " + content.media.repeatLabel
                    shortcut: content.runtime.shellHint("MediaContent.repeat")
                    active: content.media.repeatState !== 0
                    activeColor: theme.toggleColor
                    enabled: content.media.repeatAvailable
                    onActivated: content.media.toggleRepeat()
                }

                MediaTransport {
                    id: fullTransport
                    anchors.verticalCenter: parent.verticalCenter
                    runtime: content.runtime
                    theme: content.theme
                    motion: content.motion
                    media: content.media
                }

                ShellAction {
                    id: playerAction
                    anchors.verticalCenter: parent.verticalCenter
                    width: implicitWidth
                    height: Math.max(46, implicitHeight)
                    runtime: content.runtime
                    theme: content.theme
                    motion: content.motion
                    compact: true
                    horizontalCompact: true
                    icon: "󰎄"
                    title: content.media.available ? "Player " + (content.media.selectedPlayerIndex + 1) + "/" + content.media.playerCount : "No player"
                    shortcut: content.runtime.shellHint("MediaContent.player")
                    active: content.media.playerCount > 1
                    enabled: content.media.playerCount > 1
                    onActivated: content.media.cyclePlayer()
                }
            }
        }

        Column {
            id: mediaActions
            width: parent.width
            anchors {
                top: transport.bottom
                horizontalCenter: parent.horizontalCenter
                topMargin: content.theme.spacing2
            }
            spacing: content.theme.spacing2
            CenteredActionFlow {
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: content.theme.spacing2

                ShellAction {
                    id: visualizerAction
                    width: implicitWidth
                    height: Math.max(42, implicitHeight)
                    runtime: content.runtime
                    theme: content.theme
                    motion: content.motion
                    compact: true
                    horizontalCompact: true
                    icon: content.visualizerMode === "bars" ? "󰕰" : "󰘮"
                    title: content.visualizerMode === "bars" ? "Bars" : "Curve"
                    shortcut: content.runtime.shellHint("MediaContent.visualizer")
                    active: true
                    onActivated: content.toggleVisualizer()
                }

                ShellAction {
                    id: lyricsAction
                    width: implicitWidth
                    height: Math.max(42, implicitHeight)
                    runtime: content.runtime
                    theme: content.theme
                    motion: content.motion
                    compact: true
                    horizontalCompact: true
                    icon: content.lyricsVisible ? "󰨖" : "󰨕"
                    title: "Lyrics"
                    shortcut: content.runtime.shellHint("MediaContent.lyrics")
                    active: content.lyricsVisible
                    activeColor: theme.toggleColor
                    onActivated: content.toggleLyrics()
                }

                ShellStepper {
                    id: seekStepper
                    runtime: content.runtime
                    theme: content.theme
                    motion: content.motion
                    title: "Seek interval"
                    readback: content.media.seekSeconds + "s"
                    decreaseShortcut: content.runtime.shellHint("MediaContent.shorter")
                    increaseShortcut: content.runtime.shellHint("MediaContent.longer")
                    canDecrease: content.media.canDecreaseSeekInterval
                    canIncrease: content.media.canIncreaseSeekInterval
                    onDecreased: content.media.adjustSeekStep(-1)
                    onIncreased: content.media.adjustSeekStep(1)
                }
            }
            CenteredActionFlow {
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: content.theme.spacing2
                ShellAction {
                    id: preferredAction
                    width: implicitWidth
                    height: Math.max(40, implicitHeight)
                    runtime: content.runtime
                    theme: content.theme
                    motion: content.motion
                    compact: true
                    horizontalCompact: true
                    title: content.media.preferredCurrent ? "Use auto selection" : "Prefer current app"
                    shortcut: content.runtime.shellHint("MediaContent.prefer")
                    active: content.media.preferredCurrent
                    activeColor: theme.toggleColor
                    enabled: content.media.available || content.media.persistentPreference !== ""
                    onActivated: content.media.togglePreferredPlayer()
                }

                ShellText {
                    runtime: content.runtime
                    theme: content.theme
                    height: Math.max(40, implicitHeight)
                    verticalAlignment: Text.AlignVCenter
                    text: content.media.preferenceStatus
                    color: content.theme.textMuted
                    font.pixelSize: content.theme.fontSize(10)
                    width: Math.min(180, implicitWidth)
                    elide: Text.ElideRight
                }
                ShellStepper {
                    id: speedStepper
                    visible: content.media.rateAvailable
                    runtime: content.runtime
                    theme: content.theme
                    motion: content.motion
                    title: "Playback speed"
                    readback: content.media.rate.toFixed(2) + "×"
                    decreaseShortcut: content.runtime.shellHint("MediaContent.rateDown")
                    increaseShortcut: content.runtime.shellHint("MediaContent.rateUp")
                    canDecrease: content.media.rateAvailable && content.media.rate > content.media.player.minRate
                    canIncrease: content.media.rateAvailable && content.media.rate < content.media.player.maxRate
                    onDecreased: content.media.adjustRate(-0.25)
                    onIncreased: content.media.adjustRate(0.25)
                }
            }
        }
    }

    onActiveFocusChanged: if (!activeFocus)
        content.motion.endKeyboardAdjustment()

    Keys.onReleased: event => {
        if (!event.isAutoRepeat && content.motion.releaseAdjustmentKey(event.key))
            event.accepted = true;
    }

    Keys.onPressed: event => {
        if (!content.engaged)
            return;
        content.motion.noteKeyDown(event.key);
        const helpKey = event.key === content.runtime.shellKeyCode("media", "Question") || (event.key === content.runtime.shellKeyCode("media", "Slash") && (content.runtime.shellModifier("media", "Shift", event.modifiers)));

        if (content.helpOpen) {
            if (helpKey || event.key === content.runtime.shellKeyCode("media", "Escape") || event.key === content.runtime.shellKeyCode("media", "Backspace")) {
                content.helpOpen = false;
                event.accepted = true;
            } else if (content.runtime.shellNavigates("media", "down", event.key)) {
                content.helpScrollRequested(1);
                event.accepted = true;
            } else if (content.runtime.shellNavigates("media", "up", event.key)) {
                content.helpScrollRequested(-1);
                event.accepted = true;
            } else if (event.key === content.runtime.shellKeyCode("media", "D") || event.key === content.runtime.shellKeyCode("media", "PageDown")) {
                content.helpScrollRequested(4);
                event.accepted = true;
            } else if (event.key === content.runtime.shellKeyCode("media", "U") || event.key === content.runtime.shellKeyCode("media", "PageUp")) {
                content.helpScrollRequested(-4);
                event.accepted = true;
            }
            return;
        }

        if (helpKey) {
            content.helpOpen = true;
            event.accepted = true;
        } else if (content.runtime.shellMatchesHint("MediaContent.close", event.key, event.modifiers)) {
            content.closeRequested();
            event.accepted = true;
        } else if (content.runtime.shellMatchesHint("MediaTransport.play", event.key, event.modifiers)) {
            fullTransport.triggerAction("play", event.isAutoRepeat);
            event.accepted = true;
        } else if (content.runtime.shellMatchesHint("MediaContent.visualizer", event.key, event.modifiers)) {
            if (!event.isAutoRepeat)
                visualizerAction.trigger();
            event.accepted = true;
        } else if (content.runtime.shellMatchesHint("MediaContent.lyrics", event.key, event.modifiers)) {
            if (!event.isAutoRepeat)
                lyricsAction.trigger();
            event.accepted = true;
        } else if (content.runtime.shellMatchesHint("MediaContent.shuffle", event.key, event.modifiers)) {
            if (!event.isAutoRepeat)
                shuffleAction.trigger();
            event.accepted = true;
        } else if (content.runtime.shellMatchesHint("MediaContent.repeat", event.key, event.modifiers)) {
            if (!event.isAutoRepeat)
                repeatAction.trigger();
            event.accepted = true;
        } else if (content.runtime.shellMatchesHint("MediaContent.prefer", event.key, event.modifiers)) {
            if (!event.isAutoRepeat)
                preferredAction.trigger();
            event.accepted = true;
        } else if (content.runtime.shellMatchesHint("MediaContent.preferReset", event.key, event.modifiers)) {
            if (!event.isAutoRepeat)
                resetPreferredAction.trigger();
            event.accepted = true;
        } else if (content.runtime.shellMatchesHint("MediaContent.rateDown", event.key, event.modifiers)) {
            if (!event.isAutoRepeat && content.media.rateAvailable)
                speedStepper.decrease();
            event.accepted = true;
        } else if (content.runtime.shellMatchesHint("MediaContent.rateUp", event.key, event.modifiers)) {
            if (!event.isAutoRepeat && content.media.rateAvailable)
                speedStepper.increase();
            event.accepted = true;
        } else if (content.media.canRaise && content.runtime.shellMatchesHint("MediaContent.raise", event.key, event.modifiers)) {
            if (!event.isAutoRepeat)
                raiseAction.trigger();
            event.accepted = true;
        } else if (content.runtime.shellMatchesHint("MediaContent.player", event.key, event.modifiers)) {
            if (!event.isAutoRepeat)
                playerAction.trigger();
            event.accepted = true;
        } else if (content.runtime.shellMatchesHint("MediaContent.shorter", event.key, event.modifiers)) {
            seekStepper.decrease();
            event.accepted = true;
        } else if (content.runtime.shellMatchesHint("MediaContent.longer", event.key, event.modifiers)) {
            seekStepper.increase();
            event.accepted = true;
        } else if (content.runtime.shellMatchesHint("MediaTransport.back", event.key, event.modifiers) || content.runtime.shellMatchesHint("MediaTransport.backArrow", event.key, event.modifiers)) {
            progressTrack.beginKeyboardAdjustment();
            fullTransport.triggerAction("back", event.isAutoRepeat);
            event.accepted = true;
        } else if (content.runtime.shellMatchesHint("MediaTransport.forward", event.key, event.modifiers) || content.runtime.shellMatchesHint("MediaTransport.forwardArrow", event.key, event.modifiers)) {
            progressTrack.beginKeyboardAdjustment();
            fullTransport.triggerAction("forward", event.isAutoRepeat);
            event.accepted = true;
        } else if (content.runtime.shellMatchesHint("MediaTransport.previous", event.key, event.modifiers)) {
            fullTransport.triggerAction("previous", event.isAutoRepeat);
            event.accepted = true;
        } else if (content.runtime.shellMatchesHint("MediaTransport.next", event.key, event.modifiers)) {
            fullTransport.triggerAction("next", event.isAutoRepeat);
            event.accepted = true;
        }
    }
}
