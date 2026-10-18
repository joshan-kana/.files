pragma ComponentBehavior: Bound
import QtQuick

Column {
    id: quick

    required property SystemState system
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property bool microphone: false
    property bool showMixer: false
    property bool inline: false
    property bool meterEnabled: false
    property int baseIndex: 0
    property int selectedAudioIndex: 0
    signal selectionRequested(int index)
    signal mixerRequested

    property bool chooserOpen: false
    property int chooserIndex: 0
    function toggleDeviceChooser(): void {
        if (devices.length === 0)
            return;
        if (chooserOpen) {
            chooserOpen = false;
        } else {
            chooserIndex = Math.max(0, devices.indexOf(device));
            chooserOpen = true;
        }
    }
    function moveDeviceSelection(delta: int): void {
        if (devices.length > 0)
            chooserIndex = (chooserIndex + delta + devices.length) % devices.length;
    }
    function selectDevice(index: int): void {
        const node = devices[index];
        if (node)
            system.selectAudioDevice(microphone, node);
        chooserOpen = false;
    }

    readonly property bool available: microphone ? system.microphoneAvailable : system.audioAvailable
    readonly property bool muted: microphone ? system.microphoneMuted : system.muted
    readonly property real level: microphone ? system.microphoneVolume : system.volume
    readonly property int percent: microphone ? system.microphoneVolumePercent : system.volumePercent
    readonly property var device: microphone ? system.audioSource : system.audioSink
    readonly property var devices: microphone ? system.inputDevices : system.outputDevices
    readonly property var streams: (microphone ? system.audioCaptureStreams : system.audioApplicationStreams).slice(0, 2)

    spacing: theme.spacing2

    Row {
        id: inlineControl
        visible: quick.inline
        width: parent.width
        height: 66
        spacing: quick.theme.spacing2

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: quick.muted ? (quick.microphone ? "󰍭" : "󰖁") : (quick.microphone ? "󰍬" : "󰕾")
            color: quick.muted ? quick.theme.warning : quick.theme.roleColor("media")
            font.family: "Symbols Nerd Font"
            font.pixelSize: quick.theme.fontSize(19)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 82
            text: (quick.selectedAudioIndex === quick.baseIndex ? "▸ " : "") + (quick.microphone ? "Input" : "Output")
            color: quick.selectedAudioIndex === quick.baseIndex ? quick.theme.accent : quick.theme.textStrong
            font.family: quick.runtime.fontMono
            font.pixelSize: quick.theme.fontSize(12)
            font.weight: Font.DemiBold
        }

        AudioPeakMeter {
            id: inlineMeter
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(106, Math.max(66, inlineControl.width * 0.15))
            height: 29
            theme: quick.theme
            node: quick.device
            muted: quick.muted
            monitoring: quick.meterEnabled
        }

        ShellSlider {
            width: Math.max(1, inlineControl.width - 82 - inlineControl.children[0].implicitWidth - inlineMeter.width - 39 - inlineMute.width - inlineDevices.width - inlineMixer.width - inlineControl.spacing * (quick.showMixer ? 7 : 6))
            anchors.verticalCenter: parent.verticalCenter
            theme: quick.theme
            motion: quick.motion
            enabled: quick.available
            value: quick.level
            animateValueChanges: true
            accentColor: quick.muted ? quick.theme.warning : quick.theme.roleColor("media")
            trackHeight: 11
            handleSize: 18
            onValueRequested: value => {
                if (quick.microphone)
                    quick.system.setMicrophoneVolume(value);
                else
                    quick.system.setVolume(value);
            }
        }

        Text {
            width: 39
            anchors.verticalCenter: parent.verticalCenter
            text: quick.muted ? "MUTE" : quick.percent + "%"
            horizontalAlignment: Text.AlignRight
            color: quick.theme.text
            font.family: quick.runtime.fontMono
            font.pixelSize: quick.theme.fontSize(11)
        }

        IconShortcutAction {
            id: inlineMute
            shortcut: quick.microphone ? "X" : "M"
            width: 44
            height: 66
            anchors.verticalCenter: parent.verticalCenter
            runtime: quick.runtime
            theme: quick.theme
            motion: quick.motion
            active: quick.muted
            activeColor: quick.theme.warning
            enabled: quick.available
            icon: quick.microphone ? (quick.muted ? "󰍭" : "󰍬") : (quick.muted ? "󰖁" : "󰕾")
            title: "Mute"
            onActivated: {
                if (quick.microphone)
                    quick.system.toggleMicrophoneMute();
                else
                    quick.system.toggleMute();
            }
        }

        IconShortcutAction {
            id: inlineDevices
            // D acts on the keyboard-selected row; never show it twice.
            shortcut: quick.selectedAudioIndex === quick.baseIndex ? "D" : ""
            width: 44
            height: 66
            anchors.verticalCenter: parent.verticalCenter
            runtime: quick.runtime
            theme: quick.theme
            motion: quick.motion
            active: quick.chooserOpen
            enabled: quick.devices.length > 0
            icon: "󰏴"
            title: "Select audio device"
            onActivated: quick.toggleDeviceChooser()
        }

        IconShortcutAction {
            id: inlineMixer
            shortcut: "A"
            visible: quick.showMixer
            width: quick.showMixer ? 44 : 0
            height: 66
            anchors.verticalCenter: parent.verticalCenter
            runtime: quick.runtime
            theme: quick.theme
            motion: quick.motion
            icon: "󰓃"
            title: "Application mixer"
            onActivated: quick.mixerRequested()
        }
    }

    Row {
        width: parent.width
        visible: !quick.inline
        height: 28
        spacing: quick.theme.spacing2

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: quick.microphone ? "󰍬" : "󰕾"
            color: quick.muted ? quick.theme.warning : quick.theme.roleColor("media")
            font.family: "Symbols Nerd Font"
            font.pixelSize: quick.theme.fontSize(16)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: (quick.selectedAudioIndex === quick.baseIndex ? "▸ " : "") + (quick.microphone ? "Input" : "Output") + "  " + (quick.muted ? "MUTED" : quick.percent + "%")
            color: quick.selectedAudioIndex === quick.baseIndex ? quick.theme.accent : quick.theme.textStrong
            font.family: quick.runtime.fontMono
            font.pixelSize: quick.theme.fontSize(11)
            font.weight: Font.DemiBold
        }
        MarqueeText {
            width: Math.max(1, parent.width - parent.children[0].implicitWidth - parent.children[1].implicitWidth - (quick.showMixer ? mixerLink.width : 0) - deviceLink.width - parent.spacing * (quick.showMixer ? 4 : 3))
            anchors.verticalCenter: parent.verticalCenter
            text: quick.device ? (quick.device.description || quick.device.name) : "Unavailable"
            alignRight: true
            color: quick.theme.textMuted
            font.family: quick.runtime.fontMono
            font.pixelSize: quick.theme.fontSize(9)
        }
        ShellAction {
            id: deviceLink
            width: 86
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            runtime: quick.runtime
            theme: quick.theme
            motion: quick.motion
            compact: true
            title: "Device"
            shortcut: "D"
            enabled: quick.devices.length > 0
            active: quick.chooserOpen
            onActivated: quick.toggleDeviceChooser()
        }
        ShellAction {
            id: mixerLink
            visible: quick.showMixer
            width: quick.showMixer ? 84 : 0
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            runtime: quick.runtime
            theme: quick.theme
            motion: quick.motion
            compact: true
            title: "Mixer"
            shortcut: "A"
            onActivated: quick.mixerRequested()
        }
    }

    ListView {
        id: deviceList
        width: parent.width
        height: quick.chooserOpen ? Math.min(4, quick.devices.length) * 40 : 0
        visible: quick.chooserOpen
        clip: true
        model: quick.devices
        currentIndex: quick.chooserIndex
        onCurrentIndexChanged: {
            if (currentIndex >= 0)
                positionViewAtIndex(currentIndex, ListView.Contain);
        }

        delegate: Row {
            id: deviceRow
            required property var modelData
            required property int index
            width: deviceList.width
            height: 38
            spacing: quick.theme.spacing2

            ShellAction {
                width: parent.width - chooserMeter.width - parent.spacing
                height: 38
                runtime: quick.runtime
                theme: quick.theme
                motion: quick.motion
                compact: true
                active: deviceRow.index === quick.chooserIndex
                title: (deviceRow.modelData === quick.device ? "✓  " : "") + (deviceRow.modelData.description || deviceRow.modelData.name)
                shortcut: deviceRow.index === quick.chooserIndex ? "↵" : ""
                onActivated: quick.selectDevice(deviceRow.index)
            }

            AudioPeakMeter {
                id: chooserMeter
                anchors.verticalCenter: parent.verticalCenter
                width: 142
                height: 27
                theme: quick.theme
                node: deviceRow.modelData
                monitoring: quick.meterEnabled && quick.chooserOpen
                muted: !!deviceRow.modelData.audio?.muted
            }
        }
    }

    Row {
        width: parent.width
        visible: !quick.inline
        height: 34
        spacing: quick.theme.spacing2

        AudioPeakMeter {
            id: rowMeter
            width: 104
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            theme: quick.theme
            node: quick.device
            muted: quick.muted
            monitoring: quick.meterEnabled && !quick.inline
        }

        ShellSlider {
            width: Math.max(1, parent.width - rowMeter.width - muteButton.width - parent.spacing * 2)
            anchors.verticalCenter: parent.verticalCenter
            theme: quick.theme
            motion: quick.motion
            enabled: quick.available
            value: quick.level
            animateValueChanges: true
            accentColor: quick.muted ? quick.theme.warning : quick.theme.roleColor("media")
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
        // Retain two delegates across transient PipeWire stream changes.
        // The underlying JS-array model must not own delegate metaobjects.
        model: 2

        delegate: Row {
            id: streamRow
            required property int index
            readonly property var stream: quick.streams[index] || null
            visible: !!stream
            width: quick.width
            height: visible ? 36 : 0
            spacing: quick.theme.spacing2

            Text {
                width: 116
                anchors.verticalCenter: parent.verticalCenter
                text: (quick.selectedAudioIndex === quick.baseIndex + streamRow.index + 1 ? "▸ " : "") + (streamRow.stream ? quick.system.streamDisplayName(streamRow.stream) : "")
                elide: Text.ElideRight
                color: quick.selectedAudioIndex === quick.baseIndex + streamRow.index + 1 ? quick.theme.accent : quick.theme.textMuted
                font.family: quick.runtime.fontMono
                font.pixelSize: quick.theme.fontSize(9)
                MouseArea {
                    anchors.fill: parent
                    onClicked: quick.selectionRequested(quick.baseIndex + streamRow.index + 1)
                }
            }
            AudioPeakMeter {
                id: streamMeter
                anchors.verticalCenter: parent.verticalCenter
                width: 105
                height: 28
                theme: quick.theme
                node: streamRow.stream
                muted: !!streamRow.stream?.audio?.muted
                monitoring: quick.meterEnabled
            }
            ShellSlider {
                width: Math.max(1, parent.width - parent.children[0].width - streamMeter.width - streamMute.width - parent.spacing * 3)
                anchors.verticalCenter: parent.verticalCenter
                theme: quick.theme
                motion: quick.motion
                value: streamRow.stream?.audio?.volume ?? 0
                animateValueChanges: true
                enabled: !!streamRow.stream?.audio
                accentColor: streamRow.stream?.audio?.muted ? quick.theme.warning : quick.theme.roleColor("media")
                trackHeight: 5
                handleSize: 12
                onValueRequested: value => quick.system.setStreamVolume(streamRow.stream, value)
            }
            ShellSurface {
                id: streamMute
                width: 30
                height: 28
                theme: quick.theme
                motion: quick.motion
                surfaceLayer: ShellSurface.Control
                selected: !!streamRow.stream?.audio?.muted
                cornerRadius: quick.theme.radiusSmall

                Text {
                    anchors.centerIn: parent
                    text: streamRow.stream?.audio?.muted ? "󰖁" : "󰕾"
                    color: streamRow.stream?.audio?.muted ? quick.theme.warning : quick.theme.textStrong
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: quick.theme.fontSize(13)
                }
                StateLayer {
                    theme: quick.theme
                    motion: quick.motion
                    cornerRadius: quick.theme.radiusSmall
                    onActivated: quick.system.toggleStreamMute(streamRow.stream)
                }
            }
        }
    }
}
