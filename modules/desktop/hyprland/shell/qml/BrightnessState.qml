import QtQuick
import Quickshell.Io

QtObject {
    id: root

    required property QtObject runtime

    property bool supported: false
    property bool initialized: false
    property string device: ""
    property int percent: 0
    property int pendingDelta: 0

    property StdioCollector queryOutput: StdioCollector {}
    property StdioCollector queryError: StdioCollector {}
    property StdioCollector adjustOutput: StdioCollector {}
    property StdioCollector adjustError: StdioCollector {}

    property Process queryProcess: Process {
        stdout: root.queryOutput
        stderr: root.queryError

        onExited: (exitCode, exitStatus) => {
            root.handleQuery(exitCode, root.queryOutput.text);
        }
    }

    property Process adjustProcess: Process {
        stdout: root.adjustOutput
        stderr: root.adjustError

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.refresh();
            else
                root.supported = false;

            root.runPending();
        }
    }

    Component.onCompleted: refresh()

    function parseInfo(output: string): bool {
        const lines = output
            .trim()
            .split("\n")
            .map(line => line.trim())
            .filter(line => line.length > 0);

        if (lines.length === 0)
            return false;

        const fields = lines[lines.length - 1].split(",");
        if (fields.length < 5)
            return false;

        const parsedPercent = parseInt(fields[3].replace("%", ""));
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
    }

    function refresh(): void {
        if (runtime.brightnessctl.length === 0 || queryProcess.running)
            return;

        queryProcess.exec([
            runtime.brightnessctl,
            "-c",
            "backlight",
            "-m",
            "info"
        ]);
    }

    function adjust(delta: int): void {
        if (runtime.brightnessctl.length === 0 || delta === 0)
            return;
        if (initialized && !supported)
            return;

        pendingDelta += delta;
        runPending();
    }

    function runPending(): void {
        if (adjustProcess.running || pendingDelta === 0)
            return;

        const delta = Math.max(-100, Math.min(100, pendingDelta));
        pendingDelta -= delta;

        const value = delta > 0
            ? "+" + delta + "%"
            : Math.abs(delta) + "%-";

        adjustProcess.exec([
            runtime.brightnessctl,
            "-c",
            "backlight",
            "-m",
            "set",
            value
        ]);
    }
}
