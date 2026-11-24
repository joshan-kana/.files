pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "EasyEffectsPresets.js" as Presets

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
    property var presets: []
    property var activePresets: ({
            input: "",
            output: ""
        })
    property bool presetsKnown: false
    property bool presetBusy: false
    property string presetError: ""
    property var requestedPreset: null
    property int confirmationAttempts: 0
    readonly property string presetStatus: presetError || (presetBusy ? "Reading effects presets…" : !presetsKnown ? "Presets not checked" : "Input: " + (activePresets.input || "None") + " · Output: " + (activePresets.output || "None"))
    property Process presetListProcess: Process {
        stdout: StdioCollector {
            id: presetListOutput
        }
        onExited: (code, status) => {
            const result = code === 0 ? Presets.parsePresets(presetListOutput.text) : null;
            if (result === null) {
                effects.presetError = "Cannot enumerate EasyEffects presets";
                effects.presetsKnown = false;
                effects.presetBusy = false;
                return;
            }
            effects.presets = result;
            effects.presetReadProcess.exec([effects.runtime.easyeffectsCli, "--last-loaded-presets"]);
        }
    }
    property Process presetReadProcess: Process {
        stdout: StdioCollector {
            id: activePresetOutput
        }
        onExited: (code, status) => {
            const result = code === 0 ? Presets.parseActive(activePresetOutput.text) : null;
            if (result !== null) {
                effects.activePresets = result;
                effects.presetsKnown = true;
            } else {
                effects.presetsKnown = false;
            }
            if (effects.requestedPreset && !Presets.confirmed(effects.requestedPreset, result)) {
                if (effects.confirmationAttempts < 3) {
                    effects.confirmationAttempts += 1;
                    effects.confirmationTimer.restart();
                    return;
                }
                effects.presetError = "Preset load not confirmed by EasyEffects";
            } else if (result === null) {
                effects.presetError = "Cannot read active EasyEffects presets";
            }
            effects.requestedPreset = null;
            effects.presetBusy = false;
        }
    }
    property Process presetActionProcess: Process {
        stderr: StdioCollector {
            id: presetActionError
        }
        onExited: (code, status) => {
            if (code !== 0) {
                effects.presetError = presetActionError.text.trim() || "Could not load EasyEffects preset";
                effects.requestedPreset = null;
                effects.presetBusy = false;
                return;
            }
            effects.confirmationTimer.restart();
        }
    }
    property Timer confirmationTimer: Timer {
        interval: 350
        onTriggered: effects.presetReadProcess.exec([effects.runtime.easyeffectsCli, "--last-loaded-presets"])
    }

    function refreshPresets(): void {
        if (!supported || presetBusy)
            return;
        presetBusy = true;
        presetError = "";
        requestedPreset = null;
        presetListProcess.exec([runtime.easyeffectsCli, "--presets"]);
    }

    function choosePreset(name: string): void {
        const preset = presets.find(entry => entry.name === name);
        if (!supported || presetBusy || !presetsKnown || !preset)
            return;
        requestedPreset = preset;
        confirmationAttempts = 1;
        presetBusy = true;
        presetError = "";
        presetActionProcess.exec([runtime.easyeffectsCli, "--load-preset", name]);
    }

    readonly property string statusLabel: !supported ? "EasyEffects unavailable" : busy ? "Applying…" : error.length > 0 ? error : !known ? "Status not checked" : bypassed ? "Effects bypassed" : "Processing enabled"

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
                effects.error = effects.awaitingConfirmation && effects.bypassed !== effects.desiredBypass ? "Processing change was not confirmed" : "";
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
        refreshPresets();
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
