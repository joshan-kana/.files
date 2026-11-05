pragma ComponentBehavior: Bound
import QtQuick

FocusScope {
    id: mixer

    required property SystemState system
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool active: false
    property int selectedIndex: 0
    readonly property var streams: (system.audioApplicationStreams || []).concat(system.audioCaptureStreams || [])

    signal closeRequested
    signal keyboardRequested

    implicitWidth: 730
    implicitHeight: header.implicitHeight + theme.spacing4 * 2 + (streams.length > 0 ? 120 : 148) + footer.implicitHeight
    visible: active
    focus: active

    onStreamsChanged: selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, streams.length - 1)))
    onActiveChanged: {
        if (active) {
            selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, streams.length - 1)));
            Qt.callLater(() => {
                if (mixer.active)
                    mixer.keyboardRequested();
            });
        }
    }

    function focusKeyboard(): void {
        if (active)
            keyboardRequested();
    }

    function selectedStream(): var {
        return streams.length > 0 ? streams[Math.max(0, Math.min(selectedIndex, streams.length - 1))] : null;
    }

    function adjustSelected(delta: real): void {
        const stream = selectedStream();
        if (stream)
            system.adjustStreamVolume(stream, delta);
    }

    function toggleSelectedMute(): void {
        const stream = selectedStream();
        if (stream)
            system.toggleStreamMute(stream);
    }

    DetailHero {
        id: header
        width: parent.width
        runtime: mixer.runtime
        theme: mixer.theme
        motion: mixer.motion
        glyph: "♫"
        glyphColor: mixer.theme.roleColor("audio")
        eyebrow: "Audio / " + mixer.streams.length + (mixer.streams.length === 1 ? " active source" : " active sources")
        title: "Application mixer"
        detail: "Live per-channel signal, volume and mute"
    }

    ListView {
        id: list
        anchors {
            top: header.bottom
            right: parent.right
            bottom: footer.top
            left: parent.left
            topMargin: mixer.theme.spacing4
            bottomMargin: mixer.theme.spacing4
        }
        model: mixer.streams.length
        orientation: ListView.Horizontal
        spacing: mixer.theme.spacing3
        clip: true
        currentIndex: mixer.selectedIndex
        boundsBehavior: Flickable.StopAtBounds
        onCurrentIndexChanged: {
            if (currentIndex >= 0)
                positionViewAtIndex(currentIndex, ListView.Contain);
        }

        delegate: ShellSurface {
            id: streamRow
            required property int index
            readonly property var stream: mixer.streams[index] || null
            readonly property bool chosen: index === mixer.selectedIndex

            width: Math.min(340, Math.max(245, (list.width - mixer.theme.spacing3) / 2))
            height: 112
            theme: mixer.theme
            motion: mixer.motion
            cornerRadius: theme.radiusMedium
            surfaceLayer: ShellSurface.Group
            fillColor: chosen ? theme.expressiveSurfaceStrong : theme.expressiveSurface
            borderColor: chosen ? theme.roleColor("audio") : "transparent"
            borderWidth: chosen ? theme.borderFocus : 0

            StateLayer {
                theme: mixer.theme
                motion: mixer.motion
                cornerRadius: mixer.theme.radiusMedium
                onActivated: mixer.selectedIndex = streamRow.index
            }

            Column {
                anchors {
                    fill: parent
                    margins: mixer.theme.spacing3
                }
                spacing: mixer.theme.spacing2

                Row {
                    width: parent.width
                    spacing: mixer.theme.spacing2

                    Column {
                        width: parent.width - volumeLabel.implicitWidth - muteButton.width - parent.spacing * 2
                        spacing: 2
                        MarqueeText {
                            width: parent.width
                            text: streamRow.stream ? mixer.system.streamDisplayName(streamRow.stream) : ""
                            color: streamRow.stream?.audio && streamRow.stream?.audio.muted ? mixer.theme.warning : mixer.theme.textStrong
                            font.family: mixer.runtime.fontMono
                            font.pixelSize: mixer.theme.fontSize(12)
                            font.weight: Font.DemiBold
                        }
                        MarqueeText {
                            width: parent.width
                            text: (mixer.system.audioCaptureStreams.indexOf(streamRow.stream) >= 0 ? "INPUT · " : "OUTPUT · ") + (streamRow.stream ? mixer.system.streamTechnicalName(streamRow.stream) : "")
                            color: mixer.theme.textMuted
                            font.family: mixer.runtime.fontMono
                            font.pixelSize: mixer.theme.fontSize(9)
                        }
                    }

                    Text {
                        id: volumeLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: streamRow.stream?.audio ? (streamRow.stream?.audio.muted ? "MUTED" : Math.round(streamRow.stream?.audio.volume * 100) + "%") : "—"
                        color: mixer.theme.audioLevelColor(!!streamRow.stream?.audio?.muted)
                        font.family: mixer.runtime.fontMono
                        font.pixelSize: mixer.theme.fontSize(10)
                        font.weight: Font.DemiBold
                    }

                    ShellSurface {
                        id: muteButton
                        anchors.verticalCenter: parent.verticalCenter
                        width: 48
                        height: 30
                        theme: mixer.theme
                        motion: mixer.motion
                        cornerRadius: mixer.theme.radiusSmall
                        surfaceLayer: ShellSurface.Control
                        selected: !!streamRow.stream?.audio?.muted

                        Text {
                            anchors.centerIn: parent
                            text: streamRow.stream?.audio?.muted ? "󰝟" : "󰕾"
                            color: streamRow.stream?.audio?.muted ? mixer.theme.warning : mixer.theme.textStrong
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: mixer.theme.fontSize(15)
                        }
                        StateLayer {
                            theme: mixer.theme
                            motion: mixer.motion
                            cornerRadius: mixer.theme.radiusSmall
                            onActivated: {
                                mixer.selectedIndex = streamRow.index;
                                mixer.system.toggleStreamMute(streamRow.stream);
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 32
                    spacing: mixer.theme.spacing3

                    AudioPeakMeter {
                        id: streamMeter
                        width: Math.min(154, Math.max(105, parent.width * 0.23))
                        height: 29
                        anchors.verticalCenter: parent.verticalCenter
                        theme: mixer.theme
                        node: streamRow.stream
                        muted: !!streamRow.stream?.audio?.muted
                        monitoring: mixer.active
                    }

                    ShellSlider {
                        width: Math.max(1, parent.width - streamMeter.width - parent.spacing)
                        anchors.verticalCenter: parent.verticalCenter
                        theme: mixer.theme
                        motion: mixer.motion
                        enabled: !!streamRow.stream?.audio
                        value: streamRow.stream?.audio ? streamRow.stream?.audio.volume : 0
                        accentColor: mixer.theme.audioLevelColor(!!streamRow.stream?.audio?.muted)
                        trackHeight: 11
                        handleSize: 19
                        onValueRequested: value => {
                            mixer.selectedIndex = streamRow.index;
                            mixer.system.setStreamVolume(streamRow.stream, value);
                        }
                    }
                }
            }
        }
    }

    ShellSurface {
        anchors.centerIn: list
        width: list.width
        height: 120
        visible: mixer.streams.length === 0
        theme: mixer.theme
        motion: mixer.motion
        surfaceLayer: ShellSurface.Group
        cornerRadius: mixer.theme.radiusLarge
        fillColor: mixer.theme.expressiveSurface

        Column {
            anchors.centerIn: parent
            spacing: mixer.theme.spacing2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰎆"
                color: mixer.theme.roleColor("audio")
                font.family: "Symbols Nerd Font"
                font.pixelSize: mixer.theme.fontSize(32)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No application audio streams"
                color: mixer.theme.textStrong
                font.family: mixer.runtime.fontMono
                font.pixelSize: mixer.theme.fontSize(13)
                font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Active applications appear here automatically"
                color: mixer.theme.textMuted
                font.family: mixer.runtime.fontMono
                font.pixelSize: mixer.theme.fontSize(10)
            }
        }
    }

    Text {
        anchors.centerIn: list
        visible: false
        text: "No applications playing audio"
        color: mixer.theme.textStrong
        font.family: mixer.runtime.fontMono
        font.pixelSize: mixer.theme.fontSize(11)
    }

    KeyHintStrip {
        id: footer
        width: parent.width
        anchors.bottom: parent.bottom
        runtime: mixer.runtime
        theme: mixer.theme
        hints: [
            {
                shortcut: "J/K · ARROWS",
                label: "Select"
            },
            {
                shortcut: "U/D · PGUP/PGDN",
                label: "Page"
            },
            {
                shortcut: "H/L · ARROWS",
                label: "Volume"
            },
            {
                shortcut: "M",
                label: "Mute"
            },
            {
                shortcut: "ESC",
                label: "Back"
            }
        ]
    }

    // One keyboard owner per hub. The parent FocusScope forwards local keys
    // here rather than racing a nested FocusScope for layer-shell focus.
    function handleKey(key: int): bool {
        if (!active)
            return false;
        if (key === Qt.Key_Escape) {
            closeRequested();
        } else if (key === Qt.Key_Up || key === Qt.Key_K) {
            selectedIndex = Math.max(0, selectedIndex - 1);
        } else if (key === Qt.Key_Down || key === Qt.Key_J) {
            selectedIndex = Math.min(Math.max(0, streams.length - 1), selectedIndex + 1);
        } else if (key === Qt.Key_U || key === Qt.Key_PageUp || key === Qt.Key_D || key === Qt.Key_PageDown) {
            const rowHeight = list.currentItem ? list.currentItem.height + list.spacing : 64;
            const rows = Math.max(1, Math.floor(list.height / Math.max(1, rowHeight) / 2));
            selectedIndex = Math.max(0, Math.min(Math.max(0, streams.length - 1), selectedIndex + ((key === Qt.Key_D || key === Qt.Key_PageDown) ? rows : -rows)));
        } else if (key === Qt.Key_Left || key === Qt.Key_H) {
            adjustSelected(-0.05);
        } else if (key === Qt.Key_Right || key === Qt.Key_L) {
            adjustSelected(0.05);
        } else if (key === Qt.Key_M) {
            toggleSelectedMute();
        } else {
            return false;
        }
        return true;
    }
}
