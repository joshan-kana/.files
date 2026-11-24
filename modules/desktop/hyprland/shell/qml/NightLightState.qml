import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    required property RuntimeConfig runtime

    property bool supported: runtime.nightLightControl.length > 0
    property bool active: false
    property bool busy: false
    property string mode: "off"
    property int temperature: 4500
    property int effectiveTemperature: 6500
    property int startMinute: 1140
    property int endMinute: 420
    property int days: 127
    property int transitionMinutes: 15
    property bool solarAvailable: false
    property double nextTransition: 0
    property string temporaryOverride: ""
    property double overrideUntil: 0
    readonly property string scheduleLabel: mode === "custom" ? "Custom schedule" : mode === "solar" ? "Sunset to sunrise" : mode === "manual" ? "Manual" : "Off"
    readonly property string statusLabel: error.length > 0 ? error : scheduleLabel + (active ? " · " + effectiveTemperature + " K" : " · neutral") + (temporaryOverride.length > 0 ? " · temporary " + temporaryOverride : "") + (nextTransition > 0 ? " · next " + Qt.formatDateTime(new Date(nextTransition * 1000), "ddd HH:mm") : "")
    property FileView liveStatus: FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/desktop-shell-night-light.json"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload();
            root.refresh();
        }
    }
    property string error: ""
    property int queuedTemperature: -1
    property var queuedSchedule: ({})
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
            } else {
                const keys = Object.keys(root.queuedSchedule);
                if (keys.length > 0) {
                    const key = keys[0];
                    const value = root.queuedSchedule[key];
                    const pending = Object.assign({}, root.queuedSchedule);
                    delete pending[key];
                    root.queuedSchedule = pending;
                    root.change(key, String(value));
                }
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
                root.effectiveTemperature = data.effectiveTemperature;
                if (!("start" in root.queuedSchedule))
                    root.startMinute = data.startMinute;
                if (!("end" in root.queuedSchedule))
                    root.endMinute = data.endMinute;
                if (!("transition" in root.queuedSchedule))
                    root.transitionMinutes = data.transitionMinutes;
                root.days = data.days;
                root.solarAvailable = data.solarAvailable;
                root.nextTransition = data.nextTransition;
                root.temporaryOverride = data.override;
                root.overrideUntil = data.until;
                root.active = data.active;
                root.supported = data.supported;
                root.error = data.error || "";
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
            if (root.queuedTemperature >= 0 || Object.keys(root.queuedSchedule).length > 0)
                root.temperatureDebounce.restart();
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
    function setScheduleField(field: string, value: real): void {
        if (!supported || !isFinite(value))
            return;
        if (field === "start") {
            startMinute = Math.round(Math.max(0, Math.min(1439, value)));
            value = startMinute;
        } else if (field === "end") {
            endMinute = Math.round(Math.max(0, Math.min(1439, value)));
            value = endMinute;
        } else if (field === "transition") {
            transitionMinutes = Math.round(Math.max(0, Math.min(60, value)));
            value = transitionMinutes;
        } else {
            return;
        }
        queuedSchedule = Object.assign({}, queuedSchedule, {
            [field]: value
        });
        temperatureDebounce.restart();
    }

    function setMode(value: string): void {
        change("mode", value);
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
    function setTemperature(target: real): void {
        if (!supported || !isFinite(target))
            return;
        adjustTemperature(Math.round(Math.max(2500, Math.min(6500, target)) / 100) * 100 - temperature);
    }
    function warmer(): void {
        adjustTemperature(-500);
    }
    function cooler(): void {
        adjustTemperature(500);
    }
}
