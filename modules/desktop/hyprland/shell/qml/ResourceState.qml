pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    required property RuntimeConfig runtime

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
    property bool cpuSampleReady: false
    property var previousCpuStats: null
    property var previousCoreStats: ({})
    property var coreUsage: []
    property var cpuHistory: []
    property var memoryHistory: []
    property var networkHistory: []
    property string networkInterface: ""
    property real networkDownload: 0
    property real networkUpload: 0
    property var previousNetworkStats: null
    property real diskTotal: 0
    property real diskUsed: 0
    readonly property real diskPercent: diskTotal > 0 ? diskUsed / diskTotal : 0
    property int diskTicks: 0
    property int sensorTicks: 0
    property real gpuPercent: -1
    property real cpuTemperature: -1
    property real gpuTemperature: -1
    readonly property int historyLength: 30

    function kibString(value: real): string {
        return (value / 1048576).toFixed(1) + " GiB";
    }

    function speedString(value: real): string {
        if (value >= 1048576)
            return (value / 1048576).toFixed(1) + " MiB/s";
        return (value / 1024).toFixed(1) + " KiB/s";
    }

    function updateHistory(values: var, value: real): var {
        return [...values, value].slice(-historyLength);
    }

    function updateCpu(stat: string): void {
        if (!active)
            return;
        const cpuLine = stat.match(/^cpu\s+([\d\s]+)/m);
        if (cpuLine) {
            const values = cpuLine[1].trim().split(/\s+/).map(Number);
            const total = values.reduce((sum, n) => sum + n, 0);
            const idle = values[3] + (values[4] || 0);
            if (previousCpuStats) {
                const elapsed = total - previousCpuStats.total;
                const idleDelta = idle - previousCpuStats.idle;
                if (elapsed > 0) {
                    cpuPercent = Math.max(0, Math.min(1, 1 - idleDelta / elapsed));
                    cpuSampleReady = true;
                }
            }
            previousCpuStats = {
                total,
                idle
            };
        }

        // Use the same /proc/stat snapshot and the same active-only 2-second
        // sampler as overall CPU usage. These are actual per-logical-core
        // deltas, not copies of the overall utilisation ring.
        const nextCoreStats = {};
        const samples = [];
        for (const line of stat.split("\n")) {
            const match = line.match(/^cpu(\d+)\s+([\d\s]+)$/);
            if (!match)
                continue;
            const index = Number(match[1]);
            const fields = match[2].trim().split(/\s+/).map(Number);
            if (fields.length < 4 || fields.some(value => !Number.isFinite(value)))
                continue;
            const total = fields.reduce((sum, value) => sum + value, 0);
            const idle = fields[3] + (fields[4] || 0);
            const previous = previousCoreStats[index];
            const elapsed = previous ? total - previous.total : 0;
            const idleDelta = previous ? idle - previous.idle : 0;
            const utilisation = elapsed > 0 ? Math.max(0, Math.min(1, 1 - idleDelta / elapsed)) : -1;
            nextCoreStats[index] = {
                total,
                idle
            };
            samples.push({
                index,
                utilisation
            });
        }
        previousCoreStats = nextCoreStats;
        coreUsage = samples.sort((a, b) => a.index - b.index);

        if (cpuSampleReady)
            cpuHistory = updateHistory(cpuHistory, cpuPercent);
    }

    function refresh(): void {
        if (!active)
            return;

        fileMeminfo.reload();
        fileStat.reload();
        fileNetDev.reload();
        fileRoute.reload();
        const mem = fileMeminfo.text();

        memoryTotal = Number(mem.match(/^MemTotal:\s*(\d+)/m)?.[1] || 0);
        memoryAvailable = Number(mem.match(/^MemAvailable:\s*(\d+)/m)?.[1] || 0);
        swapTotal = Number(mem.match(/^SwapTotal:\s*(\d+)/m)?.[1] || 0);
        swapFree = Number(mem.match(/^SwapFree:\s*(\d+)/m)?.[1] || 0);

        memoryHistory = updateHistory(memoryHistory, memoryPercent);

        const defaultRoute = fileRoute.text().split("\n").slice(1).map(line => line.trim().split(/\s+/)).find(fields => fields.length > 2 && fields[1] === "00000000");
        const activeInterface = defaultRoute ? defaultRoute[0] : "";
        if (activeInterface !== networkInterface) {
            networkInterface = activeInterface;
            previousNetworkStats = null;
        }
        const networkLine = fileNetDev.text().split("\n").find(line => line.split(":")[0].trim() === activeInterface);
        if (activeInterface && networkLine) {
            const fields = networkLine.split(":")[1].trim().split(/\s+/);
            const receive = Number(fields[0]);
            const transmit = Number(fields[8]);
            const now = Date.now();
            if (Number.isFinite(receive) && Number.isFinite(transmit)) {
                if (previousNetworkStats) {
                    const elapsed = (now - previousNetworkStats.time) / 1000;
                    if (elapsed > 0.1) {
                        networkDownload = Math.max(0, (receive - previousNetworkStats.receive) / elapsed);
                        networkUpload = Math.max(0, (transmit - previousNetworkStats.transmit) / elapsed);
                    }
                }
                previousNetworkStats = {
                    receive,
                    transmit,
                    time: now
                };
            }
        } else {
            networkDownload = 0;
            networkUpload = 0;
        }
        networkHistory = updateHistory(networkHistory, networkDownload + networkUpload);
        if (++sensorTicks >= 5) {
            sensorTicks = 0;
            if (runtime.resourceProbe.length > 0 && !sensorProcess.running)
                sensorProcess.exec([runtime.resourceProbe]);
        }
        if (++diskTicks >= 5) {
            diskTicks = 0;
            if (!diskProcess.running)
                diskProcess.exec(["df", "-Pk", "/"]);
        }
    }

    onActiveChanged: {
        if (active) {
            previousCpuStats = null;
            previousCoreStats = {};
            cpuSampleReady = false;
            cpuPercent = 0;
            coreUsage = [];
            cpuHistory = [];
            memoryHistory = [];
            networkHistory = [];
            previousNetworkStats = null;
            diskTicks = 4;
            sensorTicks = 4;
            refresh();
        }
    }

    property FileView fileMeminfo: FileView {
        path: "/proc/meminfo"
    }
    property FileView fileStat: FileView {
        path: "/proc/stat"
        // reload() is asynchronous; reading text() immediately afterwards
        // returns the previous snapshot. Calculate deltas only when loaded.
        onLoaded: root.updateCpu(text())
    }
    property FileView fileNetDev: FileView {
        path: "/proc/net/dev"
    }
    property FileView fileRoute: FileView {
        path: "/proc/net/route"
    }
    property StdioCollector diskOutput: StdioCollector {}
    property Process diskProcess: Process {
        stdout: root.diskOutput
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                return;
            const fields = root.diskOutput.text.trim().split("\n").slice(1)[0]?.trim().split(/\s+/) || [];
            if (fields.length >= 4) {
                root.diskTotal = Number(fields[1]) || 0;
                root.diskUsed = Number(fields[2]) || 0;
            }
        }
    }
    property StdioCollector sensorOutput: StdioCollector {}
    property Process sensorProcess: Process {
        stdout: root.sensorOutput
        onExited: (exitCode, exitStatus) => {
            if (!root.active || exitCode !== 0)
                return;
            try {
                const result = JSON.parse(root.sensorOutput.text);
                root.gpuPercent = typeof result.gpuPercent === "number" ? Math.max(0, Math.min(100, result.gpuPercent)) : -1;
                root.cpuTemperature = typeof result.cpuMilliC === "number" ? result.cpuMilliC / 1000 : -1;
                root.gpuTemperature = typeof result.gpuMilliC === "number" ? result.gpuMilliC / 1000 : -1;
            } catch (error) {
                root.gpuPercent = -1;
                root.cpuTemperature = -1;
                root.gpuTemperature = -1;
            }
        }
    }
    property Timer updater: Timer {
        interval: 2000
        repeat: true
        running: root.active
        onTriggered: root.refresh()
    }
}
