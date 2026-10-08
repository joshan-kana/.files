import QtQuick

FocusScope {
    id: content

    required property QtObject media
    required property QtObject spectrum
    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

    property bool engaged: false
    property bool helpOpen: false
    property string visualizerMode: "bars"
    property bool scrubbing: false
    property real scrubFraction: 0
    readonly property var helpBindings: [
        {
            key: "SPACE",
            action: media.playing ? "Pause playback" : "Play"
        },
        {
            key: "H/L · ←/→",
            action: "Seek five seconds"
        },
        {
            key: ", / .",
            action: "Previous / next track"
        },
        {
            key: "V",
            action: "Switch visualizer"
        },
        {
            key: "ESC",
            action: "Close now playing"
        }
    ]

    signal closeRequested

    implicitWidth: 812
    implicitHeight: 422
    focus: engaged

    onEngagedChanged: {
        if (engaged) {
            keyboardFocus.forceActiveFocus();
        } else {
            helpOpen = false;
            scrubbing = false;
        }
    }

    SpectrumScale {
        id: spectrumScale
        lowHz: spectrum.lowHz
        highHz: spectrum.highHz
    }

    Timer {
        interval: 250
        repeat: true
        running: content.engaged && media.playing && media.available
        onTriggered: media.refreshPosition()
    }

    function toggleVisualizer(): void {
        visualizerMode = visualizerMode === "bars" ? "curve" : "bars";
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

        Row {
            id: header
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: theme.spacing4

            ShellSurface {
                width: 112
                height: 112
                theme: content.theme
                motion: content.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: theme.radiusLarge
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 0
                    source: media.artUrl
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectCrop
                    visible: media.artUrl.length > 0
                }

                Text {
                    anchors.centerIn: parent
                    visible: media.artUrl.length === 0
                    text: "♫"
                    color: theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(36)
                }
            }

            Column {
                width: header.width - 132 - header.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: theme.spacing2

                Text {
                    text: media.available ? "Now playing" : "Media"
                    color: theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(12)
                    font.weight: Font.Medium
                }

                Text {
                    width: parent.width
                    text: media.title
                    color: theme.textStrong
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(22)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: media.artist || media.identity || "No MPRIS player connected"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(13)
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: media.album.length > 0
                    text: media.album
                    color: theme.textMuted
                    opacity: 0.72
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(10)
                    elide: Text.ElideRight
                }
            }
        }

        Column {
            id: spectrumSlot
            anchors {
                top: header.bottom
                left: parent.left
                right: parent.right
                topMargin: theme.spacing4
            }
            spacing: 0

            ShellSurface {
                width: parent.width
                height: 118
                theme: content.theme
                motion: content.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: theme.radiusMedium
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
                            duration: content.scrubbing ? 0 : motion.fast
                            easing.type: motion.enterType
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
                            duration: motion.fast
                            easing.type: motion.enterType
                        }
                    }
                }

                Item {
                    id: frequencyLabels

                    height: 18
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        left: parent.left
                        rightMargin: theme.spacing3
                        bottomMargin: theme.spacing1
                        leftMargin: theme.spacing3
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
                            color: theme.textMuted
                            opacity: 0.62
                            font.family: runtime.fontMono
                            font.pixelSize: theme.fontSize(8)
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
                topMargin: theme.spacing5
            }
            spacing: theme.spacing3

            ShellSlider {
                id: progressTrack

                width: parent.width
                theme: content.theme
                motion: content.motion
                from: 0
                to: 1
                value: {
                    if (!media.available || media.length <= 0)
                        return 0;
                    return content.scrubbing ? content.scrubFraction : Math.max(0, Math.min(1, media.position / media.length));
                }
                enabled: media.seekable && media.length > 0
                accentColor: theme.accent
                trackHeight: 8
                handleSize: 18

                onInteractionStarted: value => {
                    content.scrubbing = true;
                    content.scrubFraction = value;
                }
                onInteractionUpdated: value => content.scrubFraction = value
                onInteractionFinished: value => {
                    content.scrubFraction = value;
                    const target = media.length * value;
                    content.scrubbing = false;
                    media.seekTo(target);
                }
            }

            Row {
                width: parent.width

                Text {
                    text: content.formatTime(content.displayedPosition())
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(10)
                }

                Item {
                    width: parent.width - parent.children[0].width - parent.children[2].width
                    height: 1
                }

                Text {
                    text: content.formatTime(media.length)
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(10)
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: theme.spacing2

                Repeater {
                    model: [
                        {
                            label: "◀",
                            hint: ",",
                            enabled: media.available,
                            action: "previous"
                        },
                        {
                            label: "−5s",
                            hint: "←",
                            enabled: media.seekable,
                            action: "back"
                        },
                        {
                            label: media.playing ? "Pause" : "Play",
                            hint: "Space",
                            enabled: media.available,
                            action: "play"
                        },
                        {
                            label: "+5s",
                            hint: "→",
                            enabled: media.seekable,
                            action: "forward"
                        },
                        {
                            label: "▶",
                            hint: ".",
                            enabled: media.available,
                            action: "next"
                        }
                    ]

                    delegate: ShellAction {
                        required property var modelData

                        width: modelData.action === "play" ? 108 : 76
                        height: 40
                        anchors.verticalCenter: parent.verticalCenter
                        runtime: content.runtime
                        theme: content.theme
                        motion: content.motion
                        compact: true
                        title: modelData.hint + "  " + modelData.label
                        active: modelData.action === "play"
                        enabled: modelData.enabled

                        onActivated: {
                            if (modelData.action === "previous")
                                media.previous();
                            else if (modelData.action === "back")
                                media.seek(-5);
                            else if (modelData.action === "play")
                                media.togglePlaying();
                            else if (modelData.action === "forward")
                                media.seek(5);
                            else if (modelData.action === "next")
                                media.next();
                        }
                    }
                }
            }
        }

        Row {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            Text {
                text: media.available ? media.identity : "MPRIS"
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(9)
                font.letterSpacing: 1
            }

            Item {
                width: parent.width - parent.children[0].width - parent.children[2].width
                height: 1
            }

            Row {
                spacing: theme.spacing2

                ShellAction {
                    width: 94
                    height: 30
                    runtime: content.runtime
                    theme: content.theme
                    motion: content.motion
                    compact: true
                    title: "V  " + content.visualizerMode.toUpperCase()
                    active: true
                    onActivated: content.toggleVisualizer()
                }

                ShellAction {
                    width: 82
                    height: 30
                    runtime: content.runtime
                    theme: content.theme
                    motion: content.motion
                    compact: true
                    title: "?  HELP"
                    onActivated: content.helpOpen = true
                }

                ShellAction {
                    width: 96
                    height: 30
                    runtime: content.runtime
                    theme: content.theme
                    motion: content.motion
                    compact: true
                    title: "ESC  CLOSE"
                    onActivated: content.closeRequested()
                }
            }
        }

        FocusScope {
            id: keyboardFocus
            anchors.fill: parent
            focus: content.engaged

            Keys.onPressed: event => {
                const helpKey = event.key === Qt.Key_Question || (event.key === Qt.Key_Slash && (event.modifiers & Qt.ShiftModifier));

                if (content.helpOpen) {
                    if (helpKey || event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                        content.helpOpen = false;
                        event.accepted = true;
                    }
                    return;
                }

                if (helpKey) {
                    content.helpOpen = true;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    content.closeRequested();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Space) {
                    media.togglePlaying();
                    event.accepted = true;
                } else if (event.key === Qt.Key_V) {
                    content.toggleVisualizer();
                    event.accepted = true;
                } else if ((event.key === Qt.Key_Left || event.key === Qt.Key_H)) {
                    media.seek(-5);
                    event.accepted = true;
                } else if ((event.key === Qt.Key_Right || event.key === Qt.Key_L)) {
                    media.seek(5);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Comma) {
                    media.previous();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Period) {
                    media.next();
                    event.accepted = true;
                }
            }
        }
    }

    WidgetHelp {
        anchors.fill: parent
        runtime: content.runtime
        theme: content.theme
        motion: content.motion
        open: content.helpOpen
        title: "Now Playing controls"
        bindings: content.helpBindings
        onDismissed: content.helpOpen = false
    }
}
