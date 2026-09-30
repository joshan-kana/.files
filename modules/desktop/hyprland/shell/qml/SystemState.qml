import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower

QtObject {
    id: system

    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property bool audioAvailable: audioSink !== null && audioSink.audio !== null
    readonly property real volume: audioAvailable ? audioSink.audio.volume : 0
    readonly property int volumePercent: Math.round(volume * 100)
    readonly property bool muted: audioAvailable ? audioSink.audio.muted : false

    readonly property var pipewireNodes: Pipewire.nodes ? Pipewire.nodes.values : []
    readonly property var audioStreams: pipewireNodes.filter(node =>
        node !== null
        && node.isStream
        && node.isSink
        && node.audio !== null)

    property PwObjectTracker audioTracker: PwObjectTracker {
        objects: [system.audioSink]
            .filter(node => node !== null)
            .concat(system.audioStreams)
    }

    readonly property var networkDevices: Networking.devices ? Networking.devices.values : []
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
    readonly property bool bluetoothEnabled: bluetoothAdapter !== null && bluetoothAdapter.enabled
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

    function streamDisplayName(stream): string {
        if (!stream)
            return "Unknown stream";

        const properties = stream.properties || {};
        return properties["application.name"]
            || properties["media.name"]
            || stream.description
            || stream.nickname
            || stream.name
            || "Audio stream";
    }

    function streamTechnicalName(stream): string {
        if (!stream)
            return "";

        const properties = stream.properties || {};
        const process = properties["application.process.binary"]
            || properties["application.process.id"]
            || "";
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
}
