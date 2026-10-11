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
    property bool refreshPending: false
    readonly property bool available: profiles.length > 0

    property StdioCollector queryOutput: StdioCollector {}
    property Process queryProcess: Process {
        stdout: root.queryOutput
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.profiles = [];
                root.current = "";
                if (root.refreshPending) {
                    root.refreshPending = false;
                    Qt.callLater(root.refresh);
                }
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
            if (root.refreshPending) {
                root.refreshPending = false;
                Qt.callLater(root.refresh);
            }
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

    property Connections runtimeChanges: Connections {
        target: root.runtime
        function onPowerprofilesctlChanged(): void {
            root.refresh();
        }
        function onPowerprofilesMonitorChanged(): void {
            root.startMonitor();
        }
    }

    // Keep the bar up to date even when Controls is closed. The daemon emits
    // PropertiesChanged for profile switches, so there is no timer polling.
    Component.onCompleted: {
        if (active && runtime) {
            refresh();
            startMonitor();
        }
    }

    onRuntimeChanged: {
        if (active && runtime) {
            refresh();
            startMonitor();
        }
    }

    onActiveChanged: {
        if (active) {
            refresh();
            startMonitor();
        } else {
            changeMonitor.running = false;
            monitorRestart.stop();
        }
    }

    property Timer monitorRestart: Timer {
        interval: 1500
        onTriggered: root.startMonitor()
    }

    property Process changeMonitor: Process {
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("member=PropertiesChanged"))
                    root.refresh();
            }
        }
        onExited: (code, status) => {
            if (root.active)
                root.monitorRestart.restart();
        }
    }

    function startMonitor(): void {
        if (active && runtime && runtime.powerprofilesMonitor.length > 0 && !changeMonitor.running)
            changeMonitor.exec([runtime.powerprofilesMonitor, "--system", "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='/org/freedesktop/UPower/PowerProfiles',arg0='org.freedesktop.UPower.PowerProfiles'"]);
    }

    function refresh(): void {
        if (!active || !runtime || runtime.powerprofilesctl.length === 0)
            return;
        if (queryProcess.running || setProcess.running) {
            refreshPending = true;
            return;
        }
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
