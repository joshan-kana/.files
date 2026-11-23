pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// EasyEffects owns the DSP graph and presets. This only queries its running
// application's documented CLI; no effects parameters or PipeWire routes are
// duplicated in desktop-shell preferences.
QtObject {
    id: effects
    required property RuntimeConfig runtime

    readonly property bool supported: runtime.easyeffects.length > 0
    property bool known: false
    property bool bypassed: false
    property bool busy: false
    property bool awaitingConfirmation: false
    property bool desiredBypass: false
    property string error: ""
    readonly property string statusLabel: !supported ? "EasyEffects unavailable"
        : busy ? "Applying…"
        : error.length > 0 ? error
        : !known ? "Status not checked"
        : bypassed ? "Effects bypassed" : "Processing enabled"

    property StdioCollector queryOutput: StdioCollector {}
    property StdioCollector queryError: StdioCollector {}
    property Process queryProcess: Process {
        stdout: effects.queryOutput
        stderr: effects.queryError
        onExited: (code, status) => {
            const result = effects.queryOutput.text.trim();
            if (code === 0 && (result === "1" || result === "2")) {
                effects.bypassed = result === "1";
                effects.known = true;
                effects.error = effects.awaitingConfirmation && effects.bypassed !== effects.desiredBypass
                    ? "Processing change was not confirmed" : "";
            } else {
                effects.known = false;
                effects.error = "Cannot read EasyEffects status";
            }
            effects.awaitingConfirmation = false;
            effects.busy = false;
        }
    }

    property StdioCollector actionError: StdioCollector {}
    property Process actionProcess: Process {
        stderr: effects.actionError
        onExited: (code, status) => {
            if (code !== 0) {
                effects.error = effects.actionError.text.trim() || "Could not change EasyEffects";
                effects.awaitingConfirmation = false;
                effects.busy = false;
                return;
            }
            effects.queryProcess.exec([effects.runtime.easyeffects, "--bypass", "3"]);
        }
    }

    function refresh(): void {
        if (!supported || busy || queryProcess.running || actionProcess.running)
            return;
        busy = true;
        error = "";
        queryProcess.exec([runtime.easyeffects, "--bypass", "3"]);
    }

    function toggleBypass(): void {
        if (!supported || busy || !known || actionProcess.running || queryProcess.running)
            return;
        desiredBypass = !bypassed;
        awaitingConfirmation = true;
        busy = true;
        error = "";
        actionProcess.exec([runtime.easyeffects, "--bypass", desiredBypass ? "1" : "2"]);
    }

    function openEditor(): void {
        if (supported)
            Quickshell.execDetached([runtime.easyeffects]);
    }
}
