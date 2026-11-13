import QtQuick
import Quickshell.Io

QtObject {
    id: root

    required property RuntimeConfig runtime

    property bool supported: false
    property bool initialized: false
    property string device: ""
    property int percent: 0
    property int pendingDelta: 0
    property int pendingTarget: -1

    property StdioCollector queryOutput: StdioCollector {}
    property StdioCollector queryError: StdioCollector {}
    property StdioCollector adjustOutput: StdioCollector {}
    property StdioCollector adjustError: StdioCollector {}

    property Process queryProcess: Process {
        stdout: root.queryOutput
        stderr: root.queryError

        onExited: (exitCode, exitStatus) => {
            root.handleQuery(exitCode, root.queryOutput.text);
            root.runPending();
        }
    }

    property Process adjustProcess: Process {
        stdout: root.adjustOutput
        stderr: root.adjustError

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.refresh();
            else {
                root.supported = false;
                root.pendingTarget = -1;
                root.pendingDelta = 0;
            }
            if (exitCode !== 0)
                root.runPending();
        }
    }

    Component.onCompleted: refresh()

    function parseInfo(output: string): bool {
        const lines = output.trim().split("\n").map(line => line.trim()).filter(line => line.length > 0);

        if (lines.length === 0)
            return false;

        const fields = lines[lines.length - 1].split(",");
        if (fields.length < 5)
            return false;

        // brightnessctl -m: device,class,current,maximum,percentage.
        // The fourth field is the maximum raw value, not the percentage.
        const parsedPercent = parseInt(fields[4].replace("%", ""));
        if (!isFinite(parsedPercent))
            return false;

        device = fields[0];
        percent = Math.max(0, Math.min(100, parsedPercent));
        return true;
    }

    function handleQuery(exitCode: int, output: string): void {
        const valid = exitCode === 0 && parseInfo(output);
        supported = valid;
        initialized = true;
        if (!valid) {
            device = "";
            pendingTarget = -1;
            pendingDelta = 0;
        }
    }

    function refresh(): void {
        if (runtime.brightnessctl.length === 0 || queryProcess.running)
            return;

        queryProcess.exec([runtime.brightnessctl, "-c", "backlight", "-m", "info"]);
    }

    function setPercent(target: real): void {
        if (!supported || !isFinite(target))
            return;
        pendingTarget = Math.max(1, Math.min(100, Math.round(target)));
        pendingDelta = 0;
        runPending();
    }

    function adjust(delta: int): void {
        if (runtime.brightnessctl.length === 0 || delta === 0)
            return;
        if (initialized && !supported)
            return;
        if (pendingTarget >= 0)
            pendingTarget = Math.max(1, Math.min(100, pendingTarget + delta));
        else
            pendingDelta += delta;
        runPending();
    }

    function runPending(): void {
        if (adjustProcess.running || queryProcess.running || !supported)
            return;

        if (pendingTarget >= 0) {
            const target = pendingTarget;
            pendingTarget = -1;
            if (target !== percent)
                adjustProcess.exec([runtime.brightnessctl, "-c", "backlight", "-m", "set", target + "%"]);
            return;
        }
        if (pendingDelta === 0)
            return;
        const delta = Math.max(-100, Math.min(100, pendingDelta));
        pendingDelta -= delta;
        const value = delta > 0 ? "+" + delta + "%" : Math.abs(delta) + "%-";
        adjustProcess.exec([runtime.brightnessctl, "-c", "backlight", "-m", "set", value]);
    }
}
