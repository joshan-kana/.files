pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "AudioHardware.js" as Hardware
import "DesktopIcons.js" as DesktopIcons

Column {
    id: panel

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property bool open: false
    property var devices: []
    property string deviceName: ""
    property int selectedIndex: 0
    property string statusText: ""
    property bool statusError: false
    property var pending: null
    property string readPurpose: ""
    property int confirmationAttempts: 0
    readonly property bool busy: readProcess.running || writeProcess.running || confirmationTimer.running || pending !== null
    readonly property int deviceIndex: devices.findIndex(device => device.name === deviceName)
    readonly property var device: deviceIndex >= 0 ? devices[deviceIndex] : null
    readonly property var choices: device?.choices || []

    visible: open
    spacing: theme.spacing2
    onOpenChanged: {
        if (open)
            refresh();
        else {
            devices = [];
            deviceName = "";
            selectedIndex = 0;
            confirmationTimer.stop();
            pending = null;
        }
    }

    function readGraph(purpose: string): void {
        readPurpose = purpose;
        readProcess.exec([runtime.timeout, "5s", runtime.pwDump]);
    }
    function refresh(): void {
        if (!open || busy)
            return;
        statusText = "Reading audio hardware…";
        statusError = false;
        readGraph("refresh");
    }
    function fail(message: string): void {
        pending = null;
        statusText = message;
        statusError = true;
    }
    function updateDevices(snapshot: var): void {
        const oldKey = choices[selectedIndex]?.key;
        devices = snapshot;
        if (!device)
            deviceName = devices[0]?.name || "";
        const index = choices.findIndex(choice => choice.key === oldKey);
        selectedIndex = Math.max(0, Math.min(choices.length - 1, index >= 0 ? index : 0));
    }
    function moveDevice(delta: int): void {
        if (busy || devices.length === 0)
            return;
        deviceName = devices[(deviceIndex + delta + devices.length) % devices.length].name;
        selectedIndex = 0;
    }
    function moveSelection(delta: int): void {
        selectedIndex = Math.max(0, Math.min(choices.length - 1, selectedIndex + delta));
    }
    function choose(index: int): void {
        const choice = choices[index];
        if (!open || busy || !device || !choice?.available || choice.active)
            return;
        selectedIndex = index;
        pending = {
            device: device.name,
            deviceSerial: device.serial,
            key: choice.key,
            serial: choice.serial
        };
        statusText = "Checking current device…";
        statusError = false;
        readGraph("verify");
    }
    Process {
        id: readProcess
        stdout: StdioCollector {
            id: graphOutput
        }
        onExited: (code, status) => {
            if (!panel.open)
                return;
            const snapshot = code === 0 ? Hardware.hardwareSnapshot(graphOutput.text) : null;
            if (snapshot === null) {
                panel.devices = [];
                panel.fail("Audio hardware unavailable");
                return;
            }
            panel.updateDevices(snapshot);
            if (panel.readPurpose === "refresh" || panel.pending === null) {
                panel.statusText = panel.devices.length ? "Native audio devices" : "No configurable hardware";
                panel.statusError = false;
                return;
            }
            const choice = Hardware.pendingChoice(snapshot, panel.pending);
            if (panel.readPurpose === "verify") {
                if (!choice?.available) {
                    panel.fail("Device or choice changed; select again");
                    return;
                }
                if (choice.active) {
                    panel.pending = null;
                    panel.statusText = "Already active";
                    return;
                }
                panel.statusText = "Applying " + choice.type + "…";
                panel.confirmationAttempts = 0;
                writeProcess.exec([panel.runtime.timeout, "5s", panel.runtime.wpctl, choice.type === "profile" ? "set-profile" : "set-route", String(choice.target), String(choice.index)]);
            } else if (choice?.active) {
                panel.pending = null;
                panel.statusText = "Confirmed by PipeWire";
                panel.statusError = false;
            } else if (panel.confirmationAttempts < 3) {
                panel.confirmationAttempts += 1;
                confirmationTimer.restart();
            } else {
                panel.fail("Change not confirmed by PipeWire");
            }
        }
    }
    Process {
        id: writeProcess
        onExited: (code, status) => {
            if (!panel.open)
                return;
            if (code !== 0) {
                panel.fail("WirePlumber rejected the change");
                return;
            }
            if (panel.pending !== null)
                confirmationTimer.restart();
            else
                panel.refresh();
        }
    }
    Timer {
        id: confirmationTimer
        interval: 300
        onTriggered: if (panel.open && panel.pending !== null)
            panel.readGraph("confirm")
    }

    function handleKey(key: int, modifiers: int, autoRepeat: bool): bool {
        if (runtime.shellMatchesHint("AudioHardwareSettings.refresh", key, modifiers)) {
            if (!autoRepeat)
                refreshAction.trigger();
        } else if (runtime.shellNavigates("mixer", "left", key)) {
            if (!autoRepeat)
                previousDevice.trigger();
        } else if (runtime.shellNavigates("mixer", "right", key)) {
            if (!autoRepeat)
                nextDevice.trigger();
        } else if (runtime.shellNavigates("mixer", "up", key)) {
            moveSelection(-1);
        } else if (runtime.shellNavigates("mixer", "down", key)) {
            moveSelection(1);
        } else if (key === runtime.shellKeyCode("mixer", "Return") || key === runtime.shellKeyCode("mixer", "Enter")) {
            if (!autoRepeat)
                (choiceList.itemAtIndex(selectedIndex) as ShellAction)?.trigger();
        } else {
            return false;
        }
        return true;
    }

    DetailHero {
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        motion: panel.motion
        glyph: DesktopIcons.glyphFor("audioMixer")
        glyphColor: panel.theme.roleColor("audio")
        eyebrow: "Audio / Device configuration"
        title: panel.device?.label || "Audio hardware"
        detail: panel.device?.profile || "Profiles and physical ports"
    }
    Row {
        width: parent.width
        spacing: panel.theme.spacing2
        ShellAction {
            id: previousDevice
            width: (parent.width - parent.spacing * 2) / 3
            height: Math.max(40, implicitHeight)
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            compact: true
            horizontalCompact: true
            title: "Previous device"
            enabled: panel.devices.length > 1 && !panel.busy
            onActivated: panel.moveDevice(-1)
        }
        ShellAction {
            id: nextDevice
            width: previousDevice.width
            height: Math.max(40, implicitHeight)
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            compact: true
            horizontalCompact: true
            title: "Next device"
            enabled: panel.devices.length > 1 && !panel.busy
            onActivated: panel.moveDevice(1)
        }
        ShellAction {
            id: refreshAction
            width: previousDevice.width
            height: Math.max(40, implicitHeight)
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            compact: true
            horizontalCompact: true
            title: "Refresh"
            shortcut: panel.runtime.shellHint("AudioHardwareSettings.refresh")
            enabled: !panel.busy
            onActivated: panel.refresh()
        }
    }
    ShellText {
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        text: panel.statusText
        color: panel.statusError ? panel.theme.warning : panel.theme.textMuted
        wrapMode: Text.WordWrap
    }
    ListView {
        id: choiceList
        width: parent.width
        height: Math.min(panel.theme.fontSize(330), contentHeight)
        clip: true
        spacing: panel.theme.spacing1
        model: panel.choices
        currentIndex: panel.selectedIndex
        boundsBehavior: Flickable.StopAtBounds
        onCurrentIndexChanged: if (currentIndex >= 0)
            positionViewAtIndex(currentIndex, ListView.Contain)
        delegate: ShellAction {
            required property int index
            required property var modelData
            width: ListView.view.width
            height: Math.max(40, implicitHeight)
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            compact: true
            horizontalCompact: true
            title: (modelData.active ? "✓ " : "") + (modelData.type === "profile" ? "Profile · " : "") + modelData.label + (!modelData.available ? " · Unavailable" : "")
            active: index === panel.selectedIndex
            shortcut: active ? panel.runtime.shellHint("AudioHardwareSettings.apply") : ""
            enabled: !panel.busy && modelData.available
            onActivated: panel.choose(index)
        }
    }
    KeyHintStrip {
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        hints: [
            {
                shortcut: panel.runtime.shellHint("AudioHardwareSettings.device"),
                label: "Device"
            },
            {
                shortcut: panel.runtime.shellHint("AudioHardwareSettings.select"),
                label: "Select profile or port"
            }
        ]
    }
}
