pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    required property RuntimeConfig runtime
    property bool active: false
    property var profiles: []
    property string current: ""
    property bool applying: false
    readonly property bool available: profiles.length > 0

    property StdioCollector queryOutput: StdioCollector {}
    property Process queryProcess: Process {
        stdout: root.queryOutput
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.profiles = [];
                root.current = "";
                return;
            }

            const values = [];
            let selected = "";
            for (const line of root.queryOutput.text.split("\n")) {
                const match = /^\s*(\*?)\s*([a-z][a-z0-9-]*):\s*$/.exec(line);
                if (!match)
                    continue;
                values.push(match[2]);
                if (match[1] === "*")
                    selected = match[2];
            }
            root.profiles = values;
            root.current = selected;
        }
    }

    property StdioCollector setError: StdioCollector {}
    property Process setProcess: Process {
        stderr: root.setError
        onExited: (exitCode, exitStatus) => {
            root.applying = false;
            root.refresh();
        }
    }

    onActiveChanged: {
        if (active)
            refresh();
    }

    property Timer updateTimer: Timer {
        interval: 30000
        repeat: true
        running: root.active
        onTriggered: root.refresh()
    }

    function refresh(): void {
        if (!active || runtime.powerprofilesctl.length === 0 || queryProcess.running || setProcess.running)
            return;
        queryProcess.exec([runtime.powerprofilesctl, "list"]);
    }

    function setProfile(profile: string): void {
        if (!available || applying || !profiles.includes(profile) || profile === current)
            return;
        applying = true;
        setProcess.exec([runtime.powerprofilesctl, "set", profile]);
    }

    function cycle(): void {
        if (!available || applying)
            return;
        const position = Math.max(0, profiles.indexOf(current));
        setProfile(profiles[(position + 1) % profiles.length]);
    }

    function label(profile: string): string {
        if (profile === "power-saver")
            return "Power saver";
        if (profile === "balanced")
            return "Balanced";
        if (profile === "performance")
            return "Performance";
        return profile;
    }
}
