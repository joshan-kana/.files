pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string phase: "idle"
    property real startedAt: 0
    property string outputPath: ""
    property bool showOutcome: false
    property bool initialStatusLoaded: false
    property real clockSeconds: Date.now() / 1000
    readonly property bool capturing: phase === "recording"
    readonly property bool finalising: phase === "finalising"
    readonly property bool visibleInBar: capturing || finalising || showOutcome
    readonly property int elapsed: Math.max(0, Math.floor(clockSeconds - startedAt))
    readonly property string elapsedLabel: Math.floor(elapsed / 3600) > 0 ? Math.floor(elapsed / 3600) + ":" + String(Math.floor(elapsed / 60) % 60).padStart(2, "0") + ":" + String(elapsed % 60).padStart(2, "0") : Math.floor(elapsed / 60) + ":" + String(elapsed % 60).padStart(2, "0")

    function update(source: string): void {
        const parts = source.trim().split("\n");
        const nextPhase = parts[0] || "idle";
        if (!["recording", "finalising", "completed", "failed"].includes(nextPhase)) {
            phase = "idle";
            showOutcome = false;
            return;
        }
        const previousPhase = phase;
        const firstStatus = !initialStatusLoaded;
        initialStatusLoaded = true;
        startedAt = Number(parts[1]) || Date.now() / 1000;
        outputPath = parts[2] || "";
        clockSeconds = Date.now() / 1000;
        phase = nextPhase;
        if (nextPhase === "completed" || nextPhase === "failed") {
            if (!firstStatus && previousPhase !== nextPhase) {
                showOutcome = true;
                outcomeTimer.restart();
            }
        } else {
            showOutcome = false;
            outcomeTimer.stop();
        }
    }

    property FileView statusFile: FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/linux-desktop-recording.state"
        watchChanges: true
        blockLoading: true
        // FileView.loaded is emitted after *each* successful reload; the
        // `loaded` property stays true and onLoadedChanged won't fire again.
        onLoaded: root.update(text())
        onFileChanged: reload()
    }

    property Timer elapsedClock: Timer {
        interval: 1000
        repeat: true
        running: root.capturing
        onTriggered: root.clockSeconds = Date.now() / 1000
    }

    property Timer outcomeTimer: Timer {
        interval: 7000
        onTriggered: root.showOutcome = false
    }
}
