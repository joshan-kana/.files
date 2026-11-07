pragma ComponentBehavior: Bound
import QtQuick

ShellSurface {
    id: deviceControl

    required property SystemState system
    required property RuntimeConfig runtime

    property bool microphone: false
    property bool compact: true
    property bool active: false
    property bool chooserOpen: false
    property int chooserIndex: 0
    property var chooserNode: null

    readonly property bool available: microphone ? system.microphoneAvailable : system.audioAvailable
    readonly property bool muted: microphone ? system.microphoneMuted : system.muted
    readonly property real level: microphone ? system.microphoneVolume : system.volume
    readonly property int percent: microphone ? system.microphoneVolumePercent : system.volumePercent
    readonly property var device: microphone ? system.audioSource : system.audioSink
    readonly property var devices: microphone ? system.inputDevices : system.outputDevices

    signal selectedRequested

    implicitHeight: deviceContents.implicitHeight + (compact ? theme.spacing3 * 2 : theme.spacing2 * 2)
    surfaceLayer: ShellSurface.Control
    cornerRadius: theme.radiusMedium
    fillColor: compact ? "transparent" : selected ? theme.expressiveSurfaceStrong : theme.expressiveSurface
    borderColor: !compact && selected ? theme.roleColor("audio") : "transparent"
    borderWidth: !compact && selected ? theme.borderFocus : 0
    Accessible.role: Accessible.Grouping
    Accessible.name: (microphone ? "Input" : "Output") + " audio, " + (muted ? "muted" : percent + " percent")

    onDevicesChanged: {
        if (!chooserOpen)
            return;
        const index = devices.indexOf(chooserNode);
        chooserIndex = index >= 0 ? index : Math.min(chooserIndex, Math.max(0, devices.length - 1));
        chooserNode = devices[chooserIndex] || null;
        if (devices.length === 0)
            chooserOpen = false;
    }

    function toggleDeviceChooser(): void {
        if (chooserOpen) {
            chooserOpen = false;
            return;
        }
        if (devices.length === 0)
            return;
        chooserIndex = Math.max(0, devices.indexOf(device));
        chooserNode = devices[chooserIndex] || null;
        chooserOpen = true;
        selectedRequested();
    }

    function moveDeviceSelection(delta: int): void {
        if (!devices.length)
            return;
        chooserIndex = (chooserIndex + delta + devices.length) % devices.length;
        chooserNode = devices[chooserIndex];
    }

    function selectDevice(index: int): void {
        const node = devices[index];
        if (node) {
            system.selectAudioDevice(microphone, node);
            selectedRequested();
        }
        chooserOpen = false;
    }

    Column {
        id: deviceContents
        x: deviceControl.compact ? 0 : deviceControl.theme.spacing2
        y: deviceControl.compact ? deviceControl.theme.spacing3 : deviceControl.theme.spacing2
        width: Math.max(1, parent.width - (deviceControl.compact ? 0 : deviceControl.theme.spacing2 * 2))
        spacing: deviceControl.compact ? deviceControl.theme.spacing2 : deviceControl.theme.spacing1

        Item {
            width: parent.width
            height: 28
            StateLayer {
                anchors.fill: parent
                theme: deviceControl.theme
                motion: deviceControl.motion
                cornerRadius: deviceControl.theme.radiusSmall
                disabled: !deviceControl.available
                Accessible.role: Accessible.Button
                Accessible.name: deviceControl.microphone ? "Toggle microphone mute" : "Toggle output mute"
                onActivated: {
                    deviceControl.selectedRequested();
                    if (deviceControl.microphone)
                        deviceControl.system.toggleMicrophoneMute();
                    else
                        deviceControl.system.toggleMute();
                }
            }
            Row {
                anchors.fill: parent
                spacing: deviceControl.theme.spacing2
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: deviceControl.microphone ? (deviceControl.muted ? "󰍭" : "󰍬") : (deviceControl.muted ? "󰖁" : "󰕾")
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: deviceControl.theme.fontSize(17)
                    color: deviceControl.theme.audioLevelColor(deviceControl.muted)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(1, parent.width - parent.children[0].implicitWidth - muteHint.implicitWidth - levelLabel.implicitWidth - parent.spacing * 3)
                    text: deviceControl.microphone ? "Input" : "Output"
                    color: deviceControl.theme.textStrong
                    font.family: deviceControl.runtime.fontMono
                    font.pixelSize: deviceControl.theme.fontSize(deviceControl.compact ? 13 : 11)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    id: levelLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: deviceControl.available ? (deviceControl.muted ? "MUTED" : deviceControl.percent + "%") : "OFFLINE"
                    color: deviceControl.theme.audioLevelColor(deviceControl.muted)
                    font.family: deviceControl.runtime.fontMono
                    font.pixelSize: deviceControl.theme.fontSize(deviceControl.compact ? 12 : 10)
                }
                KeyHint {
                    id: muteHint
                    anchors.verticalCenter: parent.verticalCenter
                    theme: deviceControl.theme
                    runtime: deviceControl.runtime
                    compact: true
                    emphasized: deviceControl.selected
                    shortcut: deviceControl.selected ? "M" : deviceControl.microphone ? "X" : ""
                }
            }
        }

        Row {
            width: parent.width
            height: 28
            spacing: deviceControl.theme.spacing2
            AudioPeakMeter {
                id: meter
                visible: !deviceControl.compact
                width: visible ? Math.min(105, Math.max(60, parent.width * 0.20)) : 0
                height: 26
                anchors.verticalCenter: parent.verticalCenter
                theme: deviceControl.theme
                node: deviceControl.device
                muted: deviceControl.muted
                monitoring: deviceControl.active && deviceControl.visible && meter.visible
            }
            ShellSlider {
                width: Math.max(1, parent.width - meter.width - (meter.visible ? parent.spacing : 0))
                anchors.verticalCenter: parent.verticalCenter
                theme: deviceControl.theme
                motion: deviceControl.motion
                enabled: deviceControl.available
                value: deviceControl.level
                animateValueChanges: true
                accentColor: deviceControl.theme.audioLevelColor(deviceControl.muted)
                trackHeight: deviceControl.compact ? 11 : 9
                handleSize: deviceControl.compact ? 20 : 16
                Accessible.role: Accessible.Slider
                Accessible.name: deviceControl.microphone ? "Microphone volume" : "Output volume"
                onInteractionStarted: deviceControl.selectedRequested()
                onValueRequested: value => {
                    deviceControl.selectedRequested();
                    if (deviceControl.microphone)
                        deviceControl.system.setMicrophoneVolume(value);
                    else
                        deviceControl.system.setVolume(value);
                }
            }
        }

        Item {
            width: parent.width
            height: deviceControl.compact ? 30 : 26
            StateLayer {
                anchors.fill: parent
                theme: deviceControl.theme
                motion: deviceControl.motion
                cornerRadius: deviceControl.theme.radiusSmall
                disabled: deviceControl.devices.length === 0
                Accessible.role: Accessible.Button
                Accessible.name: deviceControl.microphone ? "Choose input device" : "Choose output device"
                onActivated: deviceControl.toggleDeviceChooser()
            }
            Row {
                anchors.fill: parent
                spacing: deviceControl.theme.spacing2
                MarqueeText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(1, parent.width - pickerHint.implicitWidth - parent.spacing)
                    text: deviceControl.device ? (deviceControl.device.description || deviceControl.device.name) : "Hardware unavailable"
                    color: deviceControl.theme.textMuted
                    font.family: deviceControl.runtime.fontMono
                    font.pixelSize: deviceControl.theme.fontSize(deviceControl.compact ? 11 : 9)
                }
                KeyHint {
                    id: pickerHint
                    anchors.verticalCenter: parent.verticalCenter
                    theme: deviceControl.theme
                    runtime: deviceControl.runtime
                    compact: true
                    emphasized: deviceControl.chooserOpen
                    shortcut: deviceControl.selected ? "P" : "⌄"
                }
            }
        }

        ListView {
            id: deviceList
            width: parent.width
            height: deviceControl.chooserOpen ? Math.min(4, deviceControl.devices.length) * 38 : 0
            visible: deviceControl.chooserOpen
            clip: true
            model: deviceControl.devices
            currentIndex: deviceControl.chooserIndex
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: {
                if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain);
            }
            delegate: ShellAction {
                required property var modelData
                required property int index
                width: deviceList.width
                height: 36
                runtime: deviceControl.runtime
                theme: deviceControl.theme
                motion: deviceControl.motion
                compact: true
                title: (modelData === deviceControl.device ? "✓  " : "") + (modelData.description || modelData.name)
                active: index === deviceControl.chooserIndex
                shortcut: index === deviceControl.chooserIndex ? "↵" : ""
                onActivated: deviceControl.selectDevice(index)
            }
        }
    }
}
