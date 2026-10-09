pragma ComponentBehavior: Bound
import QtQuick

Column {
    id: quick

    required property SystemState system
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property bool microphone: false

    readonly property bool available: microphone ? system.microphoneAvailable : system.audioAvailable
    readonly property bool muted: microphone ? system.microphoneMuted : system.muted
    readonly property real level: microphone ? system.microphoneVolume : system.volume
    readonly property int percent: microphone ? system.microphoneVolumePercent : system.volumePercent
    readonly property var device: microphone ? system.audioSource : system.audioSink
    readonly property var streams: (microphone ? system.audioCaptureStreams : system.audioApplicationStreams).slice(0, 2)

    spacing: theme.spacing2

    Row {
        width: parent.width
        height: 20
        spacing: quick.theme.spacing2

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: quick.microphone ? "󰍬" : "󰕾"
            color: quick.muted ? quick.theme.warning : quick.theme.accent
            font.family: "Symbols Nerd Font"
            font.pixelSize: quick.theme.fontSize(16)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: (quick.microphone ? "Input" : "Output") + "  " + (quick.muted ? "MUTED" : quick.percent + "%")
            color: quick.theme.textStrong
            font.family: quick.runtime.fontMono
            font.pixelSize: quick.theme.fontSize(11)
            font.weight: Font.DemiBold
        }
        Text {
            width: Math.max(1, parent.width - parent.children[0].implicitWidth - parent.children[1].implicitWidth - parent.spacing * 2)
            anchors.verticalCenter: parent.verticalCenter
            text: quick.device ? (quick.device.description || quick.device.name) : "Unavailable"
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
            color: quick.theme.textMuted
            font.family: quick.runtime.fontMono
            font.pixelSize: quick.theme.fontSize(9)
        }
    }

    Row {
        width: parent.width
        height: 34
        spacing: quick.theme.spacing2

        ShellSlider {
            width: Math.max(1, parent.width - muteButton.width - parent.spacing)
            anchors.verticalCenter: parent.verticalCenter
            theme: quick.theme
            motion: quick.motion
            enabled: quick.available
            value: quick.level
            accentColor: quick.muted ? quick.theme.warning : quick.theme.accent
            trackHeight: 7
            handleSize: 15
            onValueRequested: value => {
                if (quick.microphone)
                    quick.system.setMicrophoneVolume(value);
                else
                    quick.system.setVolume(value);
            }
        }

        ShellSurface {
            id: muteButton
            width: 42
            height: 32
            theme: quick.theme
            motion: quick.motion
            surfaceLayer: ShellSurface.Control
            cornerRadius: quick.theme.radiusSmall
            selected: quick.muted
            enabled: quick.available

            Text {
                anchors.centerIn: parent
                text: quick.microphone ? (quick.muted ? "󰍭" : "󰍬") : (quick.muted ? "󰖁" : "󰕾")
                color: quick.muted ? quick.theme.warning : quick.theme.textStrong
                font.family: "Symbols Nerd Font"
                font.pixelSize: quick.theme.fontSize(17)
            }
            StateLayer {
                theme: quick.theme
                motion: quick.motion
                cornerRadius: quick.theme.radiusSmall
                disabled: !quick.available
                onActivated: {
                    if (quick.microphone)
                        quick.system.toggleMicrophoneMute();
                    else
                        quick.system.toggleMute();
                }
            }
        }
    }

    Repeater {
        model: quick.streams

        delegate: Row {
            id: streamRow
            required property var modelData
            width: quick.width
            height: 30
            spacing: quick.theme.spacing2

            Text {
                width: 116
                anchors.verticalCenter: parent.verticalCenter
                text: quick.system.streamDisplayName(streamRow.modelData)
                elide: Text.ElideRight
                color: quick.theme.textMuted
                font.family: quick.runtime.fontMono
                font.pixelSize: quick.theme.fontSize(9)
            }
            ShellSlider {
                width: Math.max(1, parent.width - parent.children[0].width - streamMute.width - parent.spacing * 2)
                anchors.verticalCenter: parent.verticalCenter
                theme: quick.theme
                motion: quick.motion
                value: streamRow.modelData.audio?.volume ?? 0
                enabled: !!streamRow.modelData.audio
                accentColor: streamRow.modelData.audio?.muted ? quick.theme.warning : quick.theme.accent
                trackHeight: 5
                handleSize: 12
                onValueRequested: value => quick.system.setStreamVolume(streamRow.modelData, value)
            }
            ShellSurface {
                id: streamMute
                width: 30
                height: 28
                theme: quick.theme
                motion: quick.motion
                surfaceLayer: ShellSurface.Control
                selected: !!streamRow.modelData.audio?.muted
                cornerRadius: quick.theme.radiusSmall

                Text {
                    anchors.centerIn: parent
                    text: streamRow.modelData.audio?.muted ? "󰖁" : "󰕾"
                    color: streamRow.modelData.audio?.muted ? quick.theme.warning : quick.theme.textStrong
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: quick.theme.fontSize(13)
                }
                StateLayer {
                    theme: quick.theme
                    motion: quick.motion
                    cornerRadius: quick.theme.radiusSmall
                    onActivated: quick.system.toggleStreamMute(streamRow.modelData)
                }
            }
        }
    }
}
