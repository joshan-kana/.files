import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panel

    required property QtObject media
    required property QtObject spectrum
    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

    property bool open: false
    property bool closing: false
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
            key: "← / →",
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

    visible: open || closing
    color: "transparent"
    focusable: open
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    WlrLayershell.namespace: "linux-desktop-media"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    SpectrumScale {
        id: spectrumScale
        lowHz: spectrum.lowHz
        highHz: spectrum.highHz
    }

    Timer {
        id: closeTimer
        interval: motion.fast
        onTriggered: panel.closing = false
    }

    Timer {
        interval: 250
        repeat: true
        running: panel.open && media.playing && media.available
        onTriggered: media.refreshPosition()
    }

    function show(): void {
        closeTimer.stop();
        closing = false;
        helpOpen = false;
        open = true;
        keyboardFocus.forceActiveFocus();
    }

    function hide(): void {
        helpOpen = false;
        scrubbing = false;
        open = false;

        if (motion.fast === 0) {
            closing = false;
        } else {
            closing = true;
            closeTimer.restart();
        }
    }

    function toggle(): void {
        if (open)
            hide();
        else
            show();
    }

    function toggleVisualizer(): void {
        visualizerMode = visualizerMode === "bars" ? "curve" : "bars";
    }

    function updateScrubFraction(mouseX: real, trackWidth: real): void {
        if (trackWidth <= 0)
            return;

        scrubFraction = Math.max(0, Math.min(1, mouseX / trackWidth));
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

    Rectangle {
        anchors.fill: parent
        color: theme.contextualScrim
        opacity: panel.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: motion.fast
                easing.type: panel.open ? motion.enterType : motion.exitType
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: panel.hide()
        }
    }

    SquircleSurface {
        id: card

        width: Math.min(panel.width - 120, 860)
        height: Math.min(panel.height - 140, 470)
        anchors.centerIn: parent

        exponent: theme.squircleExponent
        cornerRadius: theme.radiusPanel
        fillColor: theme.panelFill
        borderColor: theme.subtleBorder
        borderWidth: theme.borderThin

        scale: panel.open ? 1 : theme.panelClosedScale
        opacity: panel.open ? 1 : 0

        Behavior on scale {
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

        Item {
            anchors.fill: parent
            anchors.margins: theme.spacing5

            Row {
                id: header
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                spacing: theme.spacing4

                SquircleSurface {
                    width: 112
                    height: 112
                    exponent: theme.squircleExponent
                    cornerRadius: theme.radiusLarge
                    fillColor: theme.surfaceRaised
                    borderColor: theme.outline
                    borderWidth: theme.borderThin

                    Image {
                        anchors.fill: parent
                        anchors.margins: 1
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
                        font.family: runtime.fontSans
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
                        font.family: runtime.fontSans
                        font.pixelSize: theme.fontSize(12)
                        font.weight: Font.Medium
                    }

                    Text {
                        width: parent.width
                        text: media.title
                        color: theme.textStrong
                        font.family: runtime.fontSans
                        font.pixelSize: theme.fontSize(22)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: media.artist || media.identity || "No MPRIS player connected"
                        color: theme.textMuted
                        font.family: runtime.fontSans
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
                    topMargin: theme.spacing5
                }
                spacing: theme.spacing2

                Row {
                    width: parent.width

                    Text {
                        text: "Spectrum  ·  20 Hz → 20 kHz"
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(10)
                        font.letterSpacing: 1.2
                    }

                    Item {
                        width: parent.width - parent.children[0].width - spectrumStatus.width
                        height: 1
                    }

                    Text {
                        id: spectrumStatus
                        text: panel.visualizerMode + "  ·  " + (spectrum.connected ? "live  ·  " + spectrum.sampleRate / 1000 + " kHz" : "standby")
                        color: spectrum.connected ? theme.positive : theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(9)
                        font.letterSpacing: 1
                    }
                }

                SquircleSurface {
                    width: parent.width
                    height: 118
                    exponent: theme.squircleExponent
                    cornerRadius: theme.radiusMedium
                    fillColor: theme.background
                    borderWidth: theme.borderThin
                    borderColor: theme.outline
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

                        visible: panel.visualizerMode === "curve" || opacity > 0.01
                        opacity: panel.visualizerMode === "curve" ? 1 : 0

                        spectrum: panel.spectrum
                        theme: panel.theme
                        frequencyScale: spectrumScale

                        Behavior on opacity {
                            NumberAnimation {
                                duration: panel.scrubbing ? 0 : motion.fast
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

                        visible: panel.visualizerMode === "bars" || opacity > 0.01
                        opacity: panel.visualizerMode === "bars" ? 1 : 0

                        spectrum: panel.spectrum
                        theme: panel.theme
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

                Rectangle {
                    id: progressTrack

                    width: parent.width
                    height: 6
                    radius: 3
                    color: theme.surfaceRaised

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        color: theme.accent
                        width: {
                            if (!media.available || media.length <= 0)
                                return 0;

                            const fraction = panel.scrubbing ? panel.scrubFraction : media.position / media.length;
                            return parent.width * Math.max(0, Math.min(1, fraction));
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: motion.fast
                                easing.type: Easing.Linear
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        enabled: media.seekable && media.length > 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                        onPressed: mouse => {
                            panel.scrubbing = true;
                            panel.updateScrubFraction(mouse.x, width);
                        }
                        onPositionChanged: mouse => {
                            if (pressed)
                                panel.updateScrubFraction(mouse.x, width);
                        }
                        onReleased: mouse => {
                            panel.updateScrubFraction(mouse.x, width);
                            const target = media.length * panel.scrubFraction;
                            panel.scrubbing = false;
                            media.seekTo(target);
                        }
                        onCanceled: panel.scrubbing = false
                    }
                }

                Row {
                    width: parent.width

                    Text {
                        text: panel.formatTime(panel.displayedPosition())
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(10)
                    }

                    Item {
                        width: parent.width - parent.children[0].width - parent.children[2].width
                        height: 1
                    }

                    Text {
                        text: panel.formatTime(media.length)
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

                        delegate: SquircleSurface {
                            required property var modelData

                            width: Math.max(66, controlLabel.implicitWidth + theme.spacing4 * 2)
                            height: 44
                            anchors.verticalCenter: parent.verticalCenter

                            exponent: theme.squircleExponent
                            cornerRadius: theme.radiusSmall
                            fillColor: modelData.action === "play" ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.16) : theme.surfaceRaised
                            borderColor: modelData.action === "play" ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.34) : theme.subtleBorder
                            borderWidth: theme.borderThin
                            opacity: modelData.enabled ? 1 : 0.45

                            Text {
                                id: controlLabel
                                anchors.centerIn: parent
                                text: modelData.label
                                color: modelData.action === "play" ? theme.accent : theme.text
                                font.family: runtime.fontSans
                                font.pixelSize: theme.fontSize(11)
                                font.weight: modelData.action === "play" ? Font.DemiBold : Font.Medium
                            }

                            Text {
                                anchors {
                                    top: parent.top
                                    right: parent.right
                                    topMargin: 4
                                    rightMargin: 6
                                }
                                text: modelData.hint
                                color: theme.textMuted
                                opacity: 0.62
                                font.family: runtime.fontMono
                                font.pixelSize: theme.fontSize(7)
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: modelData.enabled
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
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
                    spacing: theme.spacing4

                    Text {
                        text: "V  " + panel.visualizerMode.toUpperCase()
                        color: theme.accent
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(9)
                        font.letterSpacing: 1

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.toggleVisualizer()
                        }
                    }

                    Text {
                        text: "?  HELP"
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(9)
                        font.letterSpacing: 1

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.helpOpen = true
                        }
                    }

                    Text {
                        text: "ESC  CLOSE"
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(9)
                        font.letterSpacing: 1
                    }
                }
            }

            FocusScope {
                id: keyboardFocus
                anchors.fill: parent
                focus: panel.open

                Keys.onPressed: event => {
                    const helpKey = event.key === Qt.Key_Question || (event.key === Qt.Key_Slash && (event.modifiers & Qt.ShiftModifier));

                    if (panel.helpOpen) {
                        if (helpKey || event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                            panel.helpOpen = false;
                            event.accepted = true;
                        }
                        return;
                    }

                    if (helpKey) {
                        panel.helpOpen = true;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        panel.hide();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Space) {
                        media.togglePlaying();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_V) {
                        panel.toggleVisualizer();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left) {
                        media.seek(-5);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right) {
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
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            open: panel.helpOpen
            title: "Now Playing controls"
            bindings: panel.helpBindings
            onDismissed: panel.helpOpen = false
        }
    }
}
