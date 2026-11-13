pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "KeyboardSemantics.js" as KeyboardSemantics

// A read-only keyboard snapshot independent of transient feedback surfaces.
// Queries run on demand and never send key events or alter keyboard state.
QtObject {
    id: root
    required property RuntimeConfig runtime

    property string capsState: "unknown"
    property string numState: "unknown"
    property string layoutName: "Unknown"
    property string deviceName: ""
    property int deviceCount: 0
    property bool stale: true
    property bool pending: false
    property var queuedReasons: []
    property var activeReasons: []
    signal refreshed(string reason)

    property StdioCollector output: StdioCollector {}
    property Process query: Process {
        stdout: root.output
        onExited: (exitCode, exitStatus) => {
            let valid = false;
            if (exitCode === 0) {
                try {
                    valid = root.applyDevices(JSON.parse(root.output.text));
                } catch (error) {
                    valid = false;
                }
            }
            root.stale = !valid;
            root.pending = false;
            const reasons = root.activeReasons;
            root.activeReasons = [];
            for (const reason of reasons)
                root.refreshed(reason);
            root.beginQuery();
        }
    }

    function applyDevices(data: var): bool {
        const state = KeyboardSemantics.snapshot(data);
        if (!state) {
            deviceCount = 0;
            capsState = "unknown";
            numState = "unknown";
            layoutName = "Unavailable";
            deviceName = "";
            return false;
        }
        deviceCount = state.deviceCount;
        deviceName = state.deviceName;
        capsState = state.capsState;
        numState = state.numState;
        layoutName = state.layoutName;
        return true;
    }

    function refresh(reason: string = "inspect"): void {
        if (!queuedReasons.includes(reason))
            queuedReasons = [...queuedReasons, reason];
        beginQuery();
    }

    function beginQuery(): void {
        if (query.running || pending || !queuedReasons.length)
            return;
        activeReasons = queuedReasons;
        queuedReasons = [];
        if (!runtime.hyprctl.length) {
            stale = true;
            for (const reason of activeReasons)
                refreshed(reason);
            activeReasons = [];
            return;
        }
        pending = true;
        query.exec([runtime.hyprctl, "-j", "devices"]);
    }

    function description(state: string): string {
        return state === "on" ? "On" : state === "off" ? "Off" : state === "mixed" ? "Mixed keyboards" : "Unknown";
    }
}
