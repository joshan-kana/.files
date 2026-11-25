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
    readonly property var groups: Hardware.choiceGroups(choices)
    readonly property var openSelector: {
        if (deviceSelector.expanded)
            return deviceSelector;
        for (let i = 0; i < groupFields.count; ++i) {
            const field = groupFields.itemAt(i) as ShellValueSelector;
            if (field?.expanded)
                return field;
        }
        return null;
    }
    function closeOtherSelectors(current: var): void {
        if (current !== deviceSelector)
            deviceSelector.cancel();
        for (let i = 0; i < groupFields.count; ++i) {
            const field = groupFields.itemAt(i) as ShellValueSelector;
            if (field && field !== current)
                field.cancel();
        }
    }

    visible: open
    spacing: theme.spacing2
    onOpenChanged: {
        if (open)
            refresh();
        else {
            deviceSelector.cancel();
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
        const oldKey = groups[selectedIndex]?.key;
        devices = snapshot;
        if (!device)
            deviceName = devices[0]?.name || "";
        const index = groups.findIndex(group => group.key === oldKey);
        selectedIndex = Math.max(0, Math.min(groups.length - 1, index >= 0 ? index : 0));
    }
    function selectDevice(index: int): void {
        if (busy || index < 0 || index >= devices.length)
            return;
        deviceName = devices[index].name;
        selectedIndex = 0;
    }
    function moveDevice(delta: int): void {
        if (devices.length > 1)
            selectDevice((deviceIndex + delta + devices.length) % devices.length);
    }
    function cancelNested(): bool {
        return openSelector ? openSelector.cancel() : false;
    }
    function moveSelection(delta: int): void {
        selectedIndex = Math.max(0, Math.min(groups.length - 1, selectedIndex + delta));
    }
    function choose(index: int): void {
        const choice = choices[index];
        if (!open || busy || !device || !choice?.available || choice.active)
            return;
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
        if (runtime.shellMatchesHint("AudioHardwareSettings.devicePicker", key, modifiers)) {
            if (!autoRepeat)
                deviceSelector.toggle();
            return true;
        }
        if (openSelector) {
            if (runtime.shellNavigates("mixer", "up", key))
                openSelector.moveHighlight(-1);
            else if (runtime.shellNavigates("mixer", "down", key))
                openSelector.moveHighlight(1);
            else if (runtime.shellMatchesHint("AudioHardwareSettings.apply", key, modifiers) || (key === runtime.shellKeyCode("mixer", "Enter") && modifiers === Qt.NoModifier)) {
                if (!autoRepeat)
                    openSelector.commit();
            }
            return true;
        }
        if (runtime.shellMatchesHint("AudioHardwareSettings.refresh", key, modifiers)) {
            if (!autoRepeat)
                refreshAction.trigger();
        } else if (runtime.shellNavigates("mixer", "left", key)) {
            if (!autoRepeat)
                moveDevice(-1);
        } else if (runtime.shellNavigates("mixer", "right", key)) {
            if (!autoRepeat)
                moveDevice(1);
        } else if (runtime.shellNavigates("mixer", "up", key)) {
            moveSelection(-1);
        } else if (runtime.shellNavigates("mixer", "down", key)) {
            moveSelection(1);
        } else if (key === runtime.shellKeyCode("mixer", "Return") || key === runtime.shellKeyCode("mixer", "Enter")) {
            if (!autoRepeat)
                (groupFields.itemAt(selectedIndex) as ShellValueSelector)?.toggle();
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
        title: "Audio hardware"
        detail: panel.device?.profile || "Profiles and physical ports"
        actions: [
            ShellUtilityAction {
                id: refreshAction
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                icon: DesktopIcons.actionGlyph("refresh")
                title: "Refresh audio hardware"
                shortcut: panel.runtime.shellHint("AudioHardwareSettings.refresh")
                enabled: !panel.busy
                onActivated: panel.refresh()
            }
        ]
    }
    ShellValueSelector {
        id: deviceSelector
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        motion: panel.motion
        title: "Device"
        shortcut: panel.runtime.shellHint("AudioHardwareSettings.devicePicker")
        confirmShortcut: panel.runtime.shellHint("AudioHardwareSettings.apply")
        options: panel.devices.map(entry => entry.label)
        selectedIndex: panel.deviceIndex
        enabled: !panel.busy
        onOpened: panel.closeOtherSelectors(deviceSelector)
        onChosen: index => panel.selectDevice(index)
    }
    ShellText {
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        visible: panel.statusError || panel.busy || panel.devices.length === 0
        text: panel.statusText
        color: panel.statusError ? panel.theme.warning : panel.theme.textMuted
        wrapMode: Text.WordWrap
    }
    Repeater {
        id: groupFields
        model: panel.groups
        delegate: ShellValueSelector {
            id: groupField
            required property int index
            required property var modelData
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            title: modelData.title
            shortcut: highlighted ? panel.runtime.shellHint("AudioHardwareSettings.apply") : ""
            confirmShortcut: panel.runtime.shellHint("AudioHardwareSettings.apply")
            options: modelData.choices.map(choice => (choice.routeName || choice.label) + (choice.available ? "" : " · Unavailable"))
            disabledIndices: modelData.choices.map((choice, i) => choice.available ? -1 : i).filter(i => i >= 0)
            selectedIndex: modelData.choices.findIndex(choice => choice.active)
            highlighted: index === panel.selectedIndex
            enabled: !panel.busy
            onOpened: {
                panel.selectedIndex = index;
                panel.closeOtherSelectors(groupField);
            }
            onChosen: i => {
                const choice = modelData.choices[i];
                if (choice)
                    panel.choose(panel.choices.findIndex(entry => entry.key === choice.key && entry.serial === choice.serial));
            }
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
                label: panel.openSelector ? "Browse choices" : "Select field"
            }
        ]
    }
}
