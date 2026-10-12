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
    readonly property bool automatic: mode === "auto"
    readonly property string detail: automatic ? "Auto · 19:00–07:00 · " + temperature + "K" : active ? "Warm · " + temperature + "K" : "Off · " + temperature + "K"

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
    function change(action: string): void {
        if (!supported || busy || actionProcess.running)
            return;
        busy = true;
        error = "";
        actionProcess.exec([runtime.nightLightControl, action]);
    }
    function toggle(): void {
        change("toggle");
    }
    function toggleAuto(): void {
        change("auto");
    }
    function warmer(): void {
        change("warmer");
    }
    function cooler(): void {
        change("cooler");
    }
}
