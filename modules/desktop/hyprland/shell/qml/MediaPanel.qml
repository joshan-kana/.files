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
    property string visualizerMode: "field"

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
        open = true;
        keyboardFocus.forceActiveFocus();
    }

    function hide(): void {
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
        color: Qt.rgba(0, 0, 0, 0.48)
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

        width: Math.min(panel.width - 70, 560)
        height: Math.min(panel.height - 120, 520)

        anchors {
            top: parent.top
            right: parent.right
            topMargin: theme.panelTopOffset
            rightMargin: theme.panelSideOffset
        }

        exponent: theme.squircleExponent
        cornerRadius: theme.radiusPanel
        fillColor: theme.panelFill
        borderColor: theme.panelBorder
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
                    width: 132
                    height: 132
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
                        font.pixelSize: 36
                    }
                }

                Column {
                    width: header.width - 132 - header.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: theme.spacing2

                    Text {
                        text: media.available ? "NOW PLAYING" : "MEDIA IDLE"
                        color: theme.accent
                        font.family: runtime.fontMono
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.8
                    }

                    Text {
                        width: parent.width
                        text: media.title
                        color: theme.textStrong
                        font.family: runtime.fontSans
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: media.artist || media.identity || "No MPRIS player connected"
                        color: theme.textMuted
                        font.family: runtime.fontSans
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: media.album.length > 0
                        text: media.album
                        color: theme.textMuted
                        opacity: 0.72
                        font.family: runtime.fontMono
                        font.pixelSize: 10
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
                        text: "SPECTRUM // 20 Hz → 20 kHz"
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: 10
                        font.letterSpacing: 1.2
                    }

                    Item {
                        width: parent.width - parent.children[0].width - spectrumStatus.width
                        height: 1
                    }

                    Text {
                        id: spectrumStatus
                        text: panel.visualizerMode.toUpperCase()
                            + " // "
                            + (spectrum.connected ? "LIVE // " + spectrum.sampleRate / 1000 + " kHz" : "STANDBY")
                        color: spectrum.connected ? theme.positive : theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 96
                    color: theme.background
                    radius: theme.radiusMedium
                    border.width: theme.borderThin
                    border.color: theme.outline
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
                            model: [
                                "20",
                                "60",
                                "250",
                                "1K",
                                "4K",
                                "20K"
                            ]

                            delegate: Text {
                                required property string modelData

                                width: frequencyLabels.width / 6
                                text: modelData
                                horizontalAlignment: Text.AlignHCenter
                                color: theme.textMuted
                                opacity: 0.62
                                font.family: runtime.fontMono
                                font.pixelSize: 8
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
                    width: parent.width
                    height: 4
                    radius: 2
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
                }

                Row {
                    width: parent.width

                    Text {
                        text: panel.formatTime(media.position)
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: 10
                    }

                    Item {
                        width: parent.width - parent.children[0].width - parent.children[2].width
                        height: 1
                    }

                    Text {
                        text: panel.formatTime(media.length)
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: 10
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: theme.spacing4

                    Text {
                        text: "←  −5s"
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: 11
                    }

                    Text {
                        text: "SPACE  " + (media.playing ? "PAUSE" : "PLAY")
                        color: media.available ? theme.accent : theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "+5s  →"
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: 11
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
                    text: media.available ? media.identity.toUpperCase() : "MPRIS"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: 9
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
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }

                    Text {
                        text: "ESC  CLOSE"
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }
                }
            }

            FocusScope {
                id: keyboardFocus
                anchors.fill: parent
                focus: panel.open

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
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
    }
}
