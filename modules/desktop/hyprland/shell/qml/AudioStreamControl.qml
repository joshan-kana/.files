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

    function beginKeyboardAdjustment(): void {
        levelSlider.beginKeyboardAdjustment();
    }

    function triggerMute(): void {
        muteButton.trigger();
    }

    signal selectedRequested
    function triggerRoute(): void {
        routeButton.trigger();
    }

    signal routeRequested
    property string routeLabel: ""
    property bool routeAvailable: false
    property bool routeOpen: false

    implicitHeight: channelContents.implicitHeight
    Accessible.role: Accessible.Grouping
    Accessible.name: displayName + ", " + (capture ? "capture" : "playback") + ", " + (muted ? "muted" : percent + " percent")

    Column {
        id: channelContents
        width: parent.width
        spacing: channel.theme.spacing1

        Item {
            width: parent.width
            height: Math.max(channel.theme.fontSize(channel.compact ? 31 : 37), muteButton.height)

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
                    width: Math.max(1, parent.width - volumeLabel.width - muteButton.width - parent.spacing * 2)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    MarqueeText {
                        width: parent.width
                        text: channel.displayName
                        color: channel.muted ? channel.theme.warning : channel.theme.textStrong
                        font.family: channel.runtime.fontSans
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
                    readonly property bool shown: channel.compact || channel.selected || channel.muted || !channel.available
                    visible: shown
                    width: shown ? labelMetrics.advanceWidth : 0
                    text: channel.available ? (channel.muted ? "Muted" : channel.percent + "%") : "Unavailable"
                    color: channel.theme.audioLevelColor(channel.muted)
                    font.family: channel.runtime.fontMono
                    font.pixelSize: channel.theme.fontSize(10)
                    font.weight: Font.DemiBold
                    TextMetrics {
                        id: labelMetrics
                        text: volumeLabel.text
                        font: volumeLabel.font
                    }
                }

                ShellAction {
                    id: muteButton
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(channel.theme.fontSize(70), implicitWidth)
                    height: Math.max(channel.compact ? 30 : 36, implicitHeight)
                    runtime: channel.runtime
                    theme: channel.theme
                    motion: channel.motion
                    iconOnly: true
                    iconHint: shortcut.length > 0
                    inlineIconHint: true
                    icon: channel.muted ? "󰝟" : "󰕾"
                    title: channel.capture ? "Mute capture stream" : "Mute application"
                    active: channel.muted
                    activeColor: channel.theme.warning
                    enabled: channel.available
                    shortcut: channel.selected ? channel.runtime.shellHint("AudioStreamControl.mute") : ""
                    Accessible.name: title + (shortcut.length > 0 ? ", " + shortcut : "")
                    onActivated: {
                        channel.selectedRequested();
                        channel.system.toggleStreamMute(channel.stream);
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: channel.theme.spacing1

            AudioPeakMeter {
                id: streamMeter
                visible: !channel.compact
                width: parent.width
                height: visible ? implicitHeight : 0
                theme: channel.theme
                node: channel.stream
                muted: channel.muted
                monitoring: channel.monitoring && channel.available
            }

            Row {
                width: parent.width
                spacing: channel.theme.spacing2
                ShellSlider {
                    id: levelSlider
                    width: Math.max(1, parent.width - levelHint.width - (levelHint.width > 0 ? parent.spacing : 0))
                    height: implicitHeight
                    theme: channel.theme
                    motion: channel.motion
                    enabled: channel.available
                    value: channel.available ? channel.stream.audio.volume : 0
                    accentColor: channel.theme.audioLevelColor(channel.muted)
                    density: channel.compact ? ShellSlider.Compact : ShellSlider.Standard
                    Accessible.role: Accessible.Slider
                    Accessible.name: channel.displayName + " volume, " + channel.percent + " percent"
                    onInteractionStarted: channel.selectedRequested()
                    onValueRequested: value => {
                        channel.selectedRequested();
                        channel.system.setStreamVolume(channel.stream, value);
                    }
                }
                KeyHint {
                    id: levelHint
                    anchors.verticalCenter: parent.verticalCenter
                    runtime: channel.runtime
                    theme: channel.theme
                    compact: true
                    visible: !channel.compact
                    width: visible ? implicitWidth : 0
                    opacity: channel.selected ? 1 : 0
                    shortcut: channel.runtime.shellHint("AudioMixerContent.level")
                }
            }
        }
        ShellAction {
            id: routeButton
            visible: !channel.compact
            width: parent.width
            height: visible ? implicitHeight : 0
            runtime: channel.runtime
            theme: channel.theme
            motion: channel.motion
            title: channel.routeLabel
            shortcut: channel.selected ? channel.runtime.shellHint("AudioDeviceControl.chooser") : ""
            compact: true
            horizontalCompact: true
            enabled: channel.routeAvailable
            active: channel.routeOpen
            onActivated: channel.routeRequested()
        }
    }
}
