import QtQuick
import Quickshell.Io

QtObject {
    id: root
    required property RuntimeConfig runtime

    property bool supported: runtime.nightLightControl.length > 0
    property bool active: false
    property bool busy: false
    property string mode: "off"
    property int temperature: 4500
    property string error: ""
    property int queuedTemperature: -1
    // Apply the last requested temperature, not every intermediate key repeat.
    property Timer temperatureDebounce: Timer {
        interval: 300
        repeat: false
        onTriggered: {
            if (root.busy || root.actionProcess.running) {
                root.temperatureDebounce.restart();
                return;
            }
            if (root.queuedTemperature >= 0) {
                const target = root.queuedTemperature;
                root.queuedTemperature = -1;
                root.change("set", String(target));
            }
        }
    }
    readonly property string detail: active ? "Warm · " + temperature + "K" : "Off · " + temperature + "K"

    property StdioCollector stateOutput: StdioCollector {}
    property StdioCollector stateError: StdioCollector {}
    property Process stateProcess: Process {
        stdout: root.stateOutput
        stderr: root.stateError
        onExited: (code, status) => {
            if (code !== 0) {
                root.supported = false;
                root.error = "Night Light backend unavailable";
                return;
            }
            try {
                const data = JSON.parse(root.stateOutput.text);
                root.mode = data.mode;
                if (root.queuedTemperature < 0)
                    root.temperature = data.temperature;
                root.active = data.active;
                root.supported = data.supported;
            } catch (exception) {
                root.error = "Cannot read Night Light status";
            }
        }
    }
    property StdioCollector actionError: StdioCollector {}
    property Process actionProcess: Process {
        stderr: root.actionError
        onExited: (code, status) => {
            root.busy = false;
            root.error = code === 0 ? "" : (root.actionError.text.trim() || "Night Light could not apply");
            root.refresh();
        }
    }
    Component.onCompleted: refresh()
    function refresh(): void {
        if (runtime.nightLightControl.length > 0 && !stateProcess.running)
            stateProcess.exec([runtime.nightLightControl, "state"]);
    }
    function change(action: string, argument: string): void {
        if (!supported || busy || actionProcess.running)
            return;
        busy = true;
        error = "";
        actionProcess.exec(argument.length > 0 ? [runtime.nightLightControl, action, argument] : [runtime.nightLightControl, action]);
    }
    function toggle(): void {
        temperatureDebounce.stop();
        queuedTemperature = -1;
        change("toggle", "");
    }
    function adjustTemperature(delta: int): void {
        if (!supported)
            return;
        const target = Math.max(2500, Math.min(6500, temperature + delta));
        if (target === temperature)
            return;
        temperature = target;
        queuedTemperature = target;
        temperatureDebounce.restart();
    }
    function warmer(): void {
        adjustTemperature(-500);
    }
    function cooler(): void {
        adjustTemperature(500);
    }
}
