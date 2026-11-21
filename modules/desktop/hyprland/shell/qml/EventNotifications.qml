pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower

// System events are reported through the existing freedesktop notification
// server. The shell retains no second toast queue, popup or notification UI.
QtObject {
    id: events

    required property RuntimeConfig runtime
    required property SystemState system
    required property PowerProfileState powerProfile
    required property NotificationState notifications

    signal displaySettingsRequested
    signal networkSettingsRequested
    signal audioSettingsRequested(bool microphone)
    signal powerSettingsRequested

    component Notice: QtObject {
        id: notice

        required property RuntimeConfig runtime
        required property NotificationState notifications
        required property string source
        property var actionTarget: null
        signal actionRequested(var target)

        property StdioCollector output: StdioCollector {}
        property Process sender: Process {
            stdout: notice.output
            onExited: (code, status) => {
                if (code === 0 && notice.output.text.trim() === "open")
                    notice.actionRequested(notice.actionTarget);
                notice.actionTarget = null;
            }
        }

        function emit(icon: string, title: string, body: string, action: string, target: var, critical: bool): void {
            // Coalesce bursts from one owner. The notification service handles
            // per-app silence, Activity history, timeout and per-output layout.
            if (!runtime.notifySend || notifications.locked || sender.running)
                return;
            const args = [runtime.notifySend, "--app-name=Desktop " + source, "--icon=" + icon, "--expire-time=6000"];
            if (critical)
                args.push("--urgency=critical");
            // Quiet/fullscreen notifications must still enter Activity history,
            // but must not leave a sender waiting for an invisible action.
            if (action && (critical || (!notifications.silent && !notifications.presentation && !notifications.outputFullscreen))) {
                actionTarget = target;
                args.push("--action=open=" + action);
            } else {
                actionTarget = null;
            }
            sender.exec(args.concat([title, body]));
        }
    }

    property Notice display: Notice {
        runtime: events.runtime
        notifications: events.notifications
        source: "Displays"
        onActionRequested: target => events.displaySettingsRequested()
    }
    property Notice audio: Notice {
        runtime: events.runtime
        notifications: events.notifications
        source: "Audio"
        onActionRequested: target => {
            const devices = target.microphone ? events.system.inputDevices : events.system.outputDevices;
            const selected = devices.find(device => String(device.id) === target.id);
            if (selected && (!target.alreadySelected))
                events.system.selectAudioDevice(target.microphone, selected);
            else
                events.audioSettingsRequested(target.microphone);
        }
    }
    property Notice network: Notice {
        runtime: events.runtime
        notifications: events.notifications
        source: "Network"
        onActionRequested: target => events.networkSettingsRequested()
    }
    property Notice power: Notice {
        runtime: events.runtime
        notifications: events.notifications
        source: "Power"
        onActionRequested: target => {
            if (target === "save" && events.powerProfile.available)
                events.powerProfile.setProfile("power-saver");
            else
                events.powerSettingsRequested();
        }
    }

    property bool ready: false
    property var knownOutputs: []
    property var knownInputs: []
    property bool knownConnected: false
    property int knownBatteryState: -1
    property int knownBatteryBand: 100

    // Skip service discovery at login and resume. This one-shot baseline is
    // not state polling; all subsequent changes come from service signals.
    property Timer initialSnapshot: Timer {
        running: true
        interval: 6000
        repeat: false
        onTriggered: {
            events.knownOutputs = events.outputIds();
            events.knownInputs = events.inputIds();
            events.knownConnected = events.system.networkConnected;
            events.knownBatteryState = events.batteryState;
            events.knownBatteryBand = events.batteryBand;
            events.ready = true;
        }
    }

    function ids(nodes: var): var {
        return nodes.filter(device => !!device).map(device => String(device.id)).sort();
    }

    function outputIds(): var {
        return ids(system.outputDevices);
    }

    function inputIds(): var {
        return ids(system.inputDevices);
    }

    readonly property string outputSignature: outputIds().join(",")
    readonly property string inputSignature: inputIds().join(",")
    readonly property int batteryState: system.batteryAvailable ? system.battery.state : UPowerDeviceState.Unknown
    readonly property int batteryBand: !system.batteryAvailable ? 100 : system.batteryPercent <= 5 ? 5 : system.batteryPercent <= 10 ? 10 : system.batteryPercent <= 20 ? 20 : 100

    function connectedDevice(microphone: bool): void {
        const devices = microphone ? system.inputDevices : system.outputDevices;
        const current = ids(devices);
        const previous = microphone ? knownInputs : knownOutputs;
        if (microphone)
            knownInputs = current;
        else
            knownOutputs = current;
        if (!ready)
            return;
        const joined = devices.find(device => !previous.includes(String(device.id)));
        if (!joined)
            return;
        const name = joined.description || joined.nickname || joined.name || (microphone ? "Microphone" : "Audio output");
        const selected = microphone ? system.audioSource : system.audioSink;
        const alreadySelected = selected && selected.id === joined.id;
        audio.emit(microphone ? "audio-input-microphone" : "audio-headphones", microphone ? "Audio input connected" : "Audio output connected", name, alreadySelected ? "Audio controls" : "Use this device", {
            microphone,
            id: String(joined.id),
            alreadySelected: !!alreadySelected
        }, false);
    }

    onOutputSignatureChanged: connectedDevice(false)
    onInputSignatureChanged: connectedDevice(true)

    property Timer networkSettle: Timer {
        interval: 1700
        repeat: false
        onTriggered: {
            const connected = events.system.networkConnected;
            if (connected === events.knownConnected)
                return;
            const previouslyConnected = events.knownConnected;
            events.knownConnected = connected;
            network.emit(connected ? "network-transmit-receive" : "network-offline", connected ? "Network restored" : "Network disconnected", connected ? events.system.networkName : "Check your connection or open network settings", connected ? "" : "Network settings", null, false);
        }
    }
    readonly property bool connected: system.networkConnected
    onConnectedChanged: if (ready)
        networkSettle.restart()

    onBatteryStateChanged: {
        const previous = knownBatteryState;
        knownBatteryState = batteryState;
        if (!ready || previous === batteryState || !system.batteryAvailable)
            return;
        if ([UPowerDeviceState.Charging, UPowerDeviceState.PendingCharge, UPowerDeviceState.FullyCharged].includes(batteryState) && [UPowerDeviceState.Discharging, UPowerDeviceState.PendingDischarge].includes(previous))
            power.emit("battery-charging", "Power connected", system.batteryPercent + "% battery", "", null, false);
        else if ([UPowerDeviceState.Discharging, UPowerDeviceState.PendingDischarge].includes(batteryState) && [UPowerDeviceState.Charging, UPowerDeviceState.PendingCharge, UPowerDeviceState.FullyCharged].includes(previous))
            power.emit("battery", "Running on battery", system.batteryPercent + "% remaining", "Power controls", "controls", false);
    }

    onBatteryBandChanged: {
        const previous = knownBatteryBand;
        knownBatteryBand = batteryBand;
        if (!ready || !system.batteryAvailable || batteryState !== UPowerDeviceState.Discharging || batteryBand >= previous || batteryBand === 100)
            return;
        power.emit("battery-caution", "Battery low: " + system.batteryPercent + "%", "Connect power or enable Power saver", powerProfile.available && powerProfile.current !== "power-saver" ? "Enable Power saver" : "", "save", batteryBand <= 10);
    }

    property Connections monitorEvents: Connections {
        target: Hyprland
        function onRawEvent(event): void {
            if (event.name !== "monitoraddedv2" && event.name !== "monitoradded")
                return;
            if (!events.ready)
                return;
            const output = event.name === "monitoraddedv2" ? String(event.data).split(",")[1] : String(event.data);
            if (!output || !Quickshell.screens.some(screen => screen.name !== output))
                return;
            events.display.emit("video-display", "Display connected", output + " · Configure arrangement and refresh rate", "Configure Displays", output, false);
        }
    }
}
