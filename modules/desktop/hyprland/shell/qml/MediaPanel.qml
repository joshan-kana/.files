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
    property string visualizerMode: "field"
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
        visualizerMode = visualizerMode === "field" ? "bars" : "field";
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

                    SpectrumField {
                        id: spectrumField

                        anchors {
                            top: parent.top
                            right: parent.right
                            bottom: frequencyLabels.top
                            left: parent.left
                            topMargin: theme.spacing2
                            rightMargin: theme.spacing2
                            leftMargin: theme.spacing2
                        }

                        visible: panel.visualizerMode === "field" || opacity > 0.01
                        opacity: panel.visualizerMode === "field" ? 1 : 0
                        active: panel.open && panel.visualizerMode === "field"

                        spectrum: panel.spectrum
                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion

                        Behavior on opacity {
                            NumberAnimation {
                                duration: motion.fast
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

                        opacity: panel.visualizerMode === "field" && spectrumField.ready ? 0.20 : 1.0

                        spectrum: panel.spectrum
                        theme: panel.theme

                        Behavior on opacity {
                            NumberAnimation {
                                duration: motion.fast
                                easing.type: motion.enterType
                            }
                        }
                    }

                    Row {
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
                            model: ["20", "60", "250", "1K", "4K", "20K"]

                            delegate: Text {
                                required property string modelData

                                width: frequencyLabels.width / 6
                                text: modelData
                                horizontalAlignment: Text.AlignHCenter
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

                            return parent.width * Math.max(0, Math.min(1, media.position / media.length));
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
                        anchors.margins: -6
                        enabled: media.available && media.length > 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: mouse => media.seekTo(media.length * Math.max(0, Math.min(1, mouse.x / width)))
                    }
                }

                Row {
                    width: parent.width

                    Text {
                        text: panel.formatTime(media.position)
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
                                label: ",  ◀",
                                enabled: media.available,
                                action: "previous"
                            },
                            {
                                label: "←  −5s",
                                enabled: media.available,
                                action: "back"
                            },
                            {
                                label: "SPACE  " + (media.playing ? "PAUSE" : "PLAY"),
                                enabled: media.available,
                                action: "play"
                            },
                            {
                                label: "+5s  →",
                                enabled: media.available,
                                action: "forward"
                            },
                            {
                                label: "▶  .",
                                enabled: media.available,
                                action: "next"
                            }
                        ]

                        delegate: SquircleSurface {
                            required property var modelData

                            width: Math.max(66, controlLabel.implicitWidth + theme.spacing4 * 2)
                            height: modelData.action === "play" ? 40 : 36
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
                                font.family: runtime.fontMono
                                font.pixelSize: theme.fontSize(10)
                                font.weight: modelData.action === "play" ? Font.DemiBold : Font.Normal
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
