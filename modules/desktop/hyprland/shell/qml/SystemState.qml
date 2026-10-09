import QtQuick
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower

QtObject {
    id: system

    // Only valid for the current shell session; do not persist an accidental stay-awake.
    property bool idleInhibited: false
    function toggleIdleInhibited(): void {
        idleInhibited = !idleInhibited;
    }

    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property bool audioAvailable: audioSink !== null && audioSink.audio !== null
    readonly property real volume: audioAvailable ? audioSink.audio.volume : 0
    readonly property int volumePercent: Math.round(volume * 100)
    readonly property bool muted: audioAvailable ? audioSink.audio.muted : false
    readonly property var audioSource: {
        const preferred = Pipewire.defaultAudioSource;
        if (preferred && preferred.audio)
            return preferred;
        // A virtual default source can lack a controllable audio interface.
        for (const node of pipewireNodes) {
            if (node && !node.isStream && !node.isSink && node.audio)
                return node;
        }
        return preferred;
    }
    readonly property bool microphoneAvailable: audioSource !== null && audioSource.audio !== null
    readonly property real microphoneVolume: microphoneAvailable ? audioSource.audio.volume : 0
    readonly property int microphoneVolumePercent: Math.round(microphoneVolume * 100)
    readonly property bool microphoneMuted: microphoneAvailable && audioSource.audio.muted

    readonly property var pipewireNodes: Pipewire.nodes ? Pipewire.nodes.values : []
    readonly property var audioStreams: pipewireNodes.filter(node => node !== null && node.isStream && node.isSink && node.audio !== null)
    readonly property var audioInputStreams: pipewireNodes.filter(node => node !== null && node.isStream && !node.isSink && node.audio !== null)
    // Shell-internal capture is not an application to adjust in the mixers.
    readonly property var audioApplicationStreams: audioStreams.filter(node => !system.streamDisplayName(node).startsWith("linux-desktop-spectrum"))
    readonly property var audioCaptureStreams: audioInputStreams.filter(node => !system.streamDisplayName(node).startsWith("linux-desktop-spectrum"))

    readonly property var outputDevices: pipewireNodes.filter(node => node && !node.isStream && node.isSink && node.audio)
    readonly property var inputDevices: pipewireNodes.filter(node => node && !node.isStream && !node.isSink && node.audio)

    function cycleAudioDevice(microphone: bool): void {
        const devices = microphone ? inputDevices : outputDevices;
        if (devices.length < 2)
            return;
        const current = microphone ? audioSource : audioSink;
        const index = devices.indexOf(current);
        const next = devices[(index + 1) % devices.length];
        if (microphone)
            Pipewire.preferredDefaultAudioSource = next;
        else
            Pipewire.preferredDefaultAudioSink = next;
    }

    property PwObjectTracker audioTracker: PwObjectTracker {
        objects: [system.audioSink, system.audioSource].filter(node => node !== null).concat(system.audioStreams).concat(system.audioInputStreams)
    }

    readonly property var networkDevices: Networking.devices ? Networking.devices.values : []
    readonly property var wifiDevice: {
        for (const device of networkDevices) {
            if (device.type === DeviceType.Wifi)
                return device;
        }

        return null;
    }
    readonly property bool wifiAvailable: wifiDevice !== null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    readonly property var wifiNetworks: wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []
    readonly property string connectivityText: NetworkConnectivity.toString(Networking.connectivity)
    readonly property var connectedNetworkDevice: {
        let wired = null;

        for (const device of networkDevices) {
            if (!device.connected)
                continue;

            if (device.type === DeviceType.Wifi)
                return device;

            if (device.type === DeviceType.Wired && wired === null)
                wired = device;
        }

        return wired;
    }

    readonly property var connectedNetwork: {
        if (!connectedNetworkDevice || !connectedNetworkDevice.networks)
            return null;

        for (const network of connectedNetworkDevice.networks.values) {
            if (network.connected)
                return network;
        }

        return null;
    }

    readonly property bool networkConnected: connectedNetworkDevice !== null
    readonly property bool wifiConnected: connectedNetworkDevice !== null && connectedNetworkDevice.type === DeviceType.Wifi
    readonly property string networkName: {
        if (!connectedNetworkDevice)
            return "Offline";

        if (connectedNetworkDevice.type === DeviceType.Wifi)
            return connectedNetwork && connectedNetwork.name ? connectedNetwork.name : "Wi-Fi";

        if (connectedNetworkDevice.type === DeviceType.Wired)
            return "ETH " + connectedNetworkDevice.name;

        return connectedNetworkDevice.name || "Connected";
    }

    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothAvailable: bluetoothAdapter !== null
    readonly property bool bluetoothEnabled: bluetoothAvailable && bluetoothAdapter.enabled
    readonly property bool bluetoothDiscovering: bluetoothAvailable && bluetoothAdapter.discovering
    readonly property var bluetoothAdapterDevices: bluetoothAvailable && bluetoothAdapter.devices ? bluetoothAdapter.devices.values : []
    readonly property var bluetoothDevices: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property int bluetoothConnectedCount: {
        let count = 0;
        for (const device of bluetoothDevices) {
            if (device.connected)
                count++;
        }
        return count;
    }

    readonly property var battery: UPower.displayDevice
    readonly property bool batteryAvailable: battery !== null && battery.ready && battery.isLaptopBattery
    readonly property int batteryPercent: batteryAvailable ? Math.round(battery.percentage * 100) : 0

    readonly property var trayItems: SystemTray.items ? SystemTray.items.values : []
    readonly property int trayCount: trayItems.length

    function setWifiEnabled(enabled: bool): void {
        Networking.wifiEnabled = enabled;
    }

    function setBluetoothEnabled(enabled: bool): void {
        if (bluetoothAvailable)
            bluetoothAdapter.enabled = enabled;
    }

    function setBluetoothDiscovering(discovering: bool): void {
        if (bluetoothAvailable && bluetoothAdapter.enabled)
            bluetoothAdapter.discovering = discovering;
    }

    function streamDisplayName(stream): string {
        if (!stream)
            return "Unknown stream";

        const properties = stream.properties || {};
        return properties["application.name"] || properties["media.name"] || stream.description || stream.nickname || stream.name || "Audio stream";
    }

    function streamTechnicalName(stream): string {
        if (!stream)
            return "";

        const properties = stream.properties || {};
        const process = properties["application.process.binary"] || properties["application.process.id"] || "";
        const media = properties["media.name"] || "";

        if (process && media && process !== media)
            return process + " // " + media;
        return process || media || stream.name || ("NODE " + stream.id);
    }

    function setStreamVolume(stream, value: real): void {
        if (!stream || !stream.audio)
            return;

        stream.audio.volume = Math.max(0, Math.min(1, value));
    }

    function adjustStreamVolume(stream, delta: real): void {
        if (!stream || !stream.audio)
            return;

        setStreamVolume(stream, stream.audio.volume + delta);
    }

    function toggleStreamMute(stream): void {
        if (stream && stream.audio)
            stream.audio.muted = !stream.audio.muted;
    }

    function setVolume(value: real): void {
        if (!audioAvailable)
            return;

        audioSink.audio.volume = Math.max(0, Math.min(1, value));
    }

    function adjustVolume(delta: real): void {
        setVolume(volume + delta);
    }

    function toggleMute(): void {
        if (audioAvailable)
            audioSink.audio.muted = !audioSink.audio.muted;
    }

    function setMicrophoneVolume(value: real): void {
        if (microphoneAvailable)
            audioSource.audio.volume = Math.max(0, Math.min(1, value));
    }

    function toggleMicrophoneMute(): void {
        if (microphoneAvailable)
            audioSource.audio.muted = !audioSource.audio.muted;
    }
}
