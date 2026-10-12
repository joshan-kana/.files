pragma ComponentBehavior: Bound
import QtQuick

FocusScope {
    id: content

    required property MediaState media
    required property SpectrumState spectrum
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool engaged: false
    property bool returnToControls: false
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
            action: content.returnToControls ? "Back to Controls" : "Close now playing"
        }
    ]

    signal closeRequested

    implicitWidth: 920
    implicitHeight: 620
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

        ShellSurface {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: header.height + content.theme.spacing4 * 2
            theme: content.theme
            motion: content.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: content.theme.radiusLarge
            luminous: true
            luminousColor: content.theme.accent
            fillColor: content.theme.blend(content.theme.groupBase, content.theme.accent, content.theme.dark ? 0.095 : 0.045)
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
                width: 168
                height: 168
                theme: content.theme
                motion: content.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: theme.radiusLarge
                clip: true

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
                    color: content.theme.accent
                    font.family: content.runtime.fontMono
                    font.pixelSize: content.theme.fontSize(48)
                }
            }

            Column {
                width: header.width - 168 - header.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: content.theme.spacing2

                Text {
                    text: content.media.available ? "Now playing" : "Media"
                    color: content.theme.accent
                    font.family: content.runtime.fontMono
                    font.pixelSize: content.theme.fontSize(12)
                    font.weight: Font.Medium
                }

                Text {
                    width: parent.width
                    text: content.media.title
                    color: content.theme.textStrong
                    font.family: content.runtime.fontMono
                    font.pixelSize: content.theme.fontSize(28)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: content.media.artist || content.media.identity || "No MPRIS player connected"
                    color: content.theme.textMuted
                    font.family: content.runtime.fontMono
                    font.pixelSize: content.theme.fontSize(13)
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: content.media.album.length > 0
                    text: content.media.album
                    color: content.theme.textMuted
                    opacity: 0.72
                    font.family: content.runtime.fontMono
                    font.pixelSize: content.theme.fontSize(10)
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
                topMargin: content.theme.spacing5
            }
            spacing: 0

            ShellSurface {
                width: parent.width
                height: 220
                theme: content.theme
                motion: content.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: theme.radiusMedium
                luminous: true
                luminousColor: content.theme.accent
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

                Item {
                    id: frequencyLabels

                    height: 18
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
                            font.family: content.runtime.fontMono
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
                topMargin: content.theme.spacing5
            }
            spacing: content.theme.spacing3

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
                    const target = content.media.length * value;
                    content.scrubbing = false;
                    content.media.seekTo(target);
                }
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

            MediaTransport {
                anchors.horizontalCenter: parent.horizontalCenter
                runtime: content.runtime
                theme: content.theme
                motion: content.motion
                media: content.media
            }
        }

        Row {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            Text {
                text: content.media.available ? content.media.identity : "MPRIS"
                color: content.theme.textMuted
                font.family: content.runtime.fontMono
                font.pixelSize: content.theme.fontSize(9)
                font.letterSpacing: 1
            }

            Item {
                width: parent.width - parent.children[0].width - parent.children[2].width
                height: 1
            }

            Row {
                spacing: content.theme.spacing2

                ShellAction {
                    width: 94
                    height: 30
                    runtime: content.runtime
                    theme: content.theme
                    motion: content.motion
                    compact: true
                    title: content.visualizerMode.toUpperCase()
                    shortcut: "V"
                    active: true
                    onActivated: content.toggleVisualizer()
                }

                ShellAction {
                    width: 36
                    height: 30
                    runtime: content.runtime
                    theme: content.theme
                    motion: content.motion
                    iconOnly: true
                    icon: "󰋗"
                    title: "Help (?)"
                    onActivated: content.helpOpen = true
                }

                ShellAction {
                    width: 96
                    height: 30
                    runtime: content.runtime
                    theme: content.theme
                    motion: content.motion
                    compact: true
                    title: content.returnToControls ? "BACK" : "CLOSE"
                    shortcut: "Esc"
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
                    content.media.togglePlaying();
                    event.accepted = true;
                } else if (event.key === Qt.Key_V) {
                    content.toggleVisualizer();
                    event.accepted = true;
                } else if ((event.key === Qt.Key_Left || event.key === Qt.Key_H)) {
                    content.media.seek(-5);
                    event.accepted = true;
                } else if ((event.key === Qt.Key_Right || event.key === Qt.Key_L)) {
                    content.media.seek(5);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Comma) {
                    content.media.previous();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Period) {
                    content.media.next();
                    event.accepted = true;
                }
            }
        }
    }
}
