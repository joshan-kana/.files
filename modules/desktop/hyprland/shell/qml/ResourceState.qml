pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    // Read only while a resource dashboard is visible.
    property bool active: false
    property real memoryTotal: 0
    property real memoryAvailable: 0
    readonly property real memoryUsed: Math.max(0, memoryTotal - memoryAvailable)
    readonly property real memoryPercent: memoryTotal > 0 ? memoryUsed / memoryTotal : 0
    property real swapTotal: 0
    property real swapFree: 0
    readonly property real swapUsed: Math.max(0, swapTotal - swapFree)
    readonly property real swapPercent: swapTotal > 0 ? swapUsed / swapTotal : 0
    property real cpuPercent: 0
    property var previousCpuStats: null
    property var cpuHistory: []
    property var memoryHistory: []
    readonly property int historyLength: 30

    function kibString(value: real): string {
        return (value / 1048576).toFixed(1) + " GiB";
    }

    function updateHistory(values: var, value: real): var {
        return [...values, value].slice(-historyLength);
    }

    function refresh(): void {
        if (!active)
            return;

        fileMeminfo.reload();
        fileStat.reload();
        const mem = fileMeminfo.text();
        const stat = fileStat.text();

        memoryTotal = Number(mem.match(/^MemTotal:\s*(\d+)/m)?.[1] || 0);
        memoryAvailable = Number(mem.match(/^MemAvailable:\s*(\d+)/m)?.[1] || 0);
        swapTotal = Number(mem.match(/^SwapTotal:\s*(\d+)/m)?.[1] || 0);
        swapFree = Number(mem.match(/^SwapFree:\s*(\d+)/m)?.[1] || 0);

        const cpuLine = stat.match(/^cpu\s+([\d\s]+)/m);
        if (cpuLine) {
            const values = cpuLine[1].trim().split(/\s+/).map(Number);
            const total = values.reduce((sum, n) => sum + n, 0);
            const idle = values[3] + (values[4] || 0);
            if (previousCpuStats) {
                const elapsed = total - previousCpuStats.total;
                const idleDelta = idle - previousCpuStats.idle;
                if (elapsed > 0)
                    cpuPercent = Math.max(0, Math.min(1, 1 - idleDelta / elapsed));
            }
            previousCpuStats = {
                total,
                idle
            };
        }

        cpuHistory = updateHistory(cpuHistory, cpuPercent);
        memoryHistory = updateHistory(memoryHistory, memoryPercent);
    }

    onActiveChanged: {
        if (active) {
            previousCpuStats = null;
            refresh();
        }
    }

    property FileView fileMeminfo: FileView {
        path: "/proc/meminfo"
    }
    property FileView fileStat: FileView {
        path: "/proc/stat"
    }
    property Timer updater: Timer {
        interval: 2000
        repeat: true
        running: root.active
        onTriggered: root.refresh()
    }
}
