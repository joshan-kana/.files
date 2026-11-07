pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: channel

    required property SystemState system
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property var stream: null
    property bool compact: false
    property bool selected: false
    property bool capture: false
    property bool monitoring: false

    readonly property bool available: !!stream?.audio
    readonly property bool muted: available && stream.audio.muted
    readonly property string displayName: stream ? system.streamDisplayName(stream) : ""
    readonly property int percent: available ? Math.round(stream.audio.volume * 100) : 0

    signal selectedRequested

    implicitHeight: compact ? 64 : 70
    Accessible.role: Accessible.Grouping
    Accessible.name: displayName + ", " + (capture ? "capture" : "playback") + ", " + (muted ? "muted" : percent + " percent")

    Column {
        anchors.fill: parent
        spacing: channel.theme.spacing1

        Item {
            width: parent.width
            height: channel.compact ? 31 : 37

            StateLayer {
                anchors.fill: parent
                theme: channel.theme
                motion: channel.motion
                cornerRadius: channel.theme.radiusSmall
                disabled: !channel.available
                Accessible.role: Accessible.Button
                Accessible.name: "Select " + channel.displayName
                onActivated: channel.selectedRequested()
            }

            Row {
                anchors.fill: parent
                spacing: channel.theme.spacing2

                Column {
                    width: Math.max(1, parent.width - volumeLabel.implicitWidth - muteButton.width - parent.spacing * 2)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    MarqueeText {
                        width: parent.width
                        text: channel.displayName
                        color: channel.muted ? channel.theme.warning : channel.theme.textStrong
                        font.family: channel.runtime.fontMono
                        font.pixelSize: channel.theme.fontSize(channel.compact ? 10 : 12)
                        font.weight: channel.selected ? Font.DemiBold : Font.Medium
                    }

                    MarqueeText {
                        width: parent.width
                        visible: !channel.compact
                        text: (channel.capture ? "INPUT · " : "OUTPUT · ") + (channel.stream ? channel.system.streamTechnicalName(channel.stream) : "")
                        color: channel.theme.textMuted
                        font.family: channel.runtime.fontMono
                        font.pixelSize: channel.theme.fontSize(9)
                    }
                }

                Text {
                    id: volumeLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: channel.available ? (channel.muted ? "MUTED" : channel.percent + "%") : "—"
                    color: channel.theme.audioLevelColor(channel.muted)
                    font.family: channel.runtime.fontMono
                    font.pixelSize: channel.theme.fontSize(10)
                    font.weight: Font.DemiBold
                }

                IconShortcutAction {
                    id: muteButton
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    height: channel.compact ? 30 : 36
                    runtime: channel.runtime
                    theme: channel.theme
                    motion: channel.motion
                    icon: channel.muted ? "󰝟" : "󰕾"
                    title: channel.capture ? "Mute capture stream" : "Mute application"
                    active: channel.muted
                    activeColor: channel.theme.warning
                    enabled: channel.available
                    shortcut: channel.selected ? "M" : ""
                    onActivated: {
                        channel.selectedRequested();
                        channel.system.toggleStreamMute(channel.stream);
                    }
                }
            }
        }

        Row {
            width: parent.width
            height: 27
            spacing: channel.theme.spacing2

            AudioPeakMeter {
                id: streamMeter
                visible: !channel.compact
                width: visible ? Math.min(154, Math.max(105, parent.width * 0.23)) : 0
                height: 27
                anchors.verticalCenter: parent.verticalCenter
                theme: channel.theme
                node: channel.stream
                muted: channel.muted
                monitoring: channel.monitoring && channel.available
            }

            ShellSlider {
                width: Math.max(1, parent.width - streamMeter.width - (streamMeter.visible ? parent.spacing : 0))
                anchors.verticalCenter: parent.verticalCenter
                theme: channel.theme
                motion: channel.motion
                enabled: channel.available
                value: channel.available ? channel.stream.audio.volume : 0
                animateValueChanges: true
                accentColor: channel.theme.audioLevelColor(channel.muted)
                trackHeight: channel.compact ? 6 : 10
                handleSize: channel.compact ? 14 : 18
                Accessible.role: Accessible.Slider
                Accessible.name: channel.displayName + " volume"
                onInteractionStarted: channel.selectedRequested()
                onValueRequested: value => {
                    channel.selectedRequested();
                    channel.system.setStreamVolume(channel.stream, value);
                }
            }
        }
    }
}
