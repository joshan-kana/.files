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

    implicitWidth: 730
    implicitHeight: header.implicitHeight + theme.spacing4 * 2 + Math.min(5, Math.max(1, streams.length)) * 112 + Math.max(0, Math.min(5, streams.length) - 1) * theme.spacing3 + footer.implicitHeight
    visible: active
    focus: active

    onStreamsChanged: selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, streams.length - 1)))
    onActiveChanged: {
        if (active) {
            selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, streams.length - 1)));
            Qt.callLater(() => keySink.forceActiveFocus());
        }
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
        model: mixer.streams
        spacing: mixer.theme.spacing3
        clip: true
        currentIndex: mixer.selectedIndex
        boundsBehavior: Flickable.StopAtBounds
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: ShellSurface {
            id: streamRow
            required property var modelData
            required property int index
            readonly property bool chosen: index === mixer.selectedIndex

            width: ListView.view.width
            height: 112
            theme: mixer.theme
            motion: mixer.motion
            cornerRadius: theme.radiusMedium
            surfaceLayer: ShellSurface.Group
            fillColor: chosen ? theme.expressiveSurfaceStrong : theme.expressiveSurface
            borderColor: chosen ? theme.accent : "transparent"
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
                        Text {
                            width: parent.width
                            text: mixer.system.streamDisplayName(streamRow.modelData)
                            color: streamRow.modelData.audio && streamRow.modelData.audio.muted ? mixer.theme.warning : mixer.theme.textStrong
                            font.family: mixer.runtime.fontMono
                            font.pixelSize: mixer.theme.fontSize(12)
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: (mixer.system.audioCaptureStreams.indexOf(streamRow.modelData) >= 0 ? "INPUT · " : "OUTPUT · ") + mixer.system.streamTechnicalName(streamRow.modelData)
                            color: mixer.theme.textMuted
                            font.family: mixer.runtime.fontMono
                            font.pixelSize: mixer.theme.fontSize(9)
                            elide: Text.ElideMiddle
                        }
                    }

                    Text {
                        id: volumeLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: streamRow.modelData.audio ? (streamRow.modelData.audio.muted ? "MUTED" : Math.round(streamRow.modelData.audio.volume * 100) + "%") : "—"
                        color: streamRow.modelData.audio && streamRow.modelData.audio.muted ? mixer.theme.warning : mixer.theme.accent
                        font.family: mixer.runtime.fontMono
                        font.pixelSize: mixer.theme.fontSize(10)
                        font.weight: Font.DemiBold
                    }

                    ShellSurface {
                        id: muteButton
                        anchors.verticalCenter: parent.verticalCenter
                        width: 46
                        height: 30
                        theme: mixer.theme
                        motion: mixer.motion
                        cornerRadius: mixer.theme.radiusSmall
                        surfaceLayer: ShellSurface.Control
                        selected: !!streamRow.modelData.audio?.muted

                        Text {
                            anchors.centerIn: parent
                            text: streamRow.modelData.audio?.muted ? "󰝟" : "󰕾"
                            color: streamRow.modelData.audio?.muted ? mixer.theme.warning : mixer.theme.textStrong
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: mixer.theme.fontSize(15)
                        }
                        StateLayer {
                            theme: mixer.theme
                            motion: mixer.motion
                            cornerRadius: mixer.theme.radiusSmall
                            onActivated: {
                                mixer.selectedIndex = streamRow.index;
                                mixer.system.toggleStreamMute(streamRow.modelData);
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
                        node: streamRow.modelData
                        muted: !!streamRow.modelData.audio?.muted
                        monitoring: mixer.active
                    }

                    ShellSlider {
                        width: Math.max(1, parent.width - streamMeter.width - parent.spacing)
                        anchors.verticalCenter: parent.verticalCenter
                        theme: mixer.theme
                        motion: mixer.motion
                        enabled: !!streamRow.modelData.audio
                        value: streamRow.modelData.audio ? streamRow.modelData.audio.volume : 0
                        accentColor: streamRow.modelData.audio?.muted ? mixer.theme.warning : mixer.theme.accent
                        trackHeight: 11
                        handleSize: 19
                        onValueRequested: value => {
                            mixer.selectedIndex = streamRow.index;
                            mixer.system.setStreamVolume(streamRow.modelData, value);
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
                color: mixer.theme.accent
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

    Text {
        id: footer
        anchors {
            right: parent.right
            bottom: parent.bottom
        }
        text: "J/K SELECT   U/D PAGE   H/L VOLUME   M MUTE   ESC BACK"
        color: mixer.theme.textMuted
        font.family: mixer.runtime.fontMono
        font.pixelSize: mixer.theme.fontKeyHint
    }

    FocusScope {
        id: keySink
        anchors.fill: parent
        focus: mixer.active

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                mixer.closeRequested();
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                mixer.selectedIndex = Math.max(0, mixer.selectedIndex - 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                mixer.selectedIndex = Math.min(Math.max(0, mixer.streams.length - 1), mixer.selectedIndex + 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_U || event.key === Qt.Key_D) {
                const rowHeight = list.currentItem ? list.currentItem.height + list.spacing : 64;
                const rows = Math.max(1, Math.floor(list.height / Math.max(1, rowHeight) / 2));
                mixer.selectedIndex = Math.max(0, Math.min(Math.max(0, mixer.streams.length - 1), mixer.selectedIndex + (event.key === Qt.Key_D ? rows : -rows)));
                event.accepted = true;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                mixer.adjustSelected(-0.05);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                mixer.adjustSelected(0.05);
                event.accepted = true;
            } else if (event.key === Qt.Key_M) {
                mixer.toggleSelectedMute();
                event.accepted = true;
            }
        }
    }
}
