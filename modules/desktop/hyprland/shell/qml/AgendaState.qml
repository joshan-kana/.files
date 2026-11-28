pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

QtObject {
    id: agenda

    required property RuntimeConfig runtime
    property bool active: false
    property string startDate: ""
    property bool loading: false
    property bool configured: false
    property string errorMessage: ""
    property var events: []
    property var calendars: []
    property var pendingCalendarChanges: []
    property bool refreshPending: false

    function refresh(): void {
        if (!active || startDate.length === 0 || runtime.agendaQuery.length === 0)
            return;
        if (fetchProcess.running) {
            refreshPending = true;
            return;
        }
        loading = true;
        errorMessage = "";
        fetchProcess.command = [runtime.agendaQuery, startDate];
        fetchProcess.running = true;
    }

    onActiveChanged: {
        if (active)
            refreshDelay.restart();
        else
            refreshDelay.stop();
    }
    onStartDateChanged: {
        if (active)
            refreshDelay.restart();
    }

    property Timer refreshDelay: Timer {
        interval: 120
        onTriggered: agenda.refresh()
    }

    property Timer periodicRefresh: Timer {
        interval: 10 * 60 * 1000
        repeat: true
        running: agenda.active
        onTriggered: agenda.refresh()
    }

    function setCalendarEnabled(id: string, enabled: bool): void {
        calendars = calendars.map(entry => entry.id === id ? Object.assign({}, entry, {
                enabled: enabled
            }) : entry);
        pendingCalendarChanges = pendingCalendarChanges.concat([
            {
                id: id,
                enabled: enabled
            }
        ]);
        applyNextCalendarChange();
    }

    function applyNextCalendarChange(): void {
        if (calendarChangeProcess.running || pendingCalendarChanges.length === 0)
            return;
        const entry = pendingCalendarChanges[0];
        pendingCalendarChanges = pendingCalendarChanges.slice(1);
        calendarChangeProcess.exec([runtime.agendaQuery, "--set-enabled", entry.id, entry.enabled ? "true" : "false"]);
    }

    property Process calendarChangeProcess: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                agenda.errorMessage = "Could not update calendar visibility";
            agenda.refresh();
            // Allow the process to transition to its idle state before the next write.
            Qt.callLater(() => agenda.applyNextCalendarChange());
        }
    }

    function setup(): void {
        if (runtime.agendaSetup.length > 0 && !setupProcess.running)
            setupProcess.exec([runtime.agendaSetup]);
    }

    property StdioCollector setupError: StdioCollector {}
    property Process setupProcess: Process {
        stderr: agenda.setupError
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                agenda.refresh();
            else
                agenda.errorMessage = agenda.setupError.text.trim() || "Could not create local calendar";
        }
    }

    property StdioCollector queryOutput: StdioCollector {}
    property StdioCollector queryError: StdioCollector {}
    property Process fetchProcess: Process {
        stdout: agenda.queryOutput
        stderr: agenda.queryError
        onExited: (exitCode, exitStatus) => {
            agenda.loading = false;
            if (exitCode === 0) {
                try {
                    const response = JSON.parse(agenda.queryOutput.text);
                    agenda.configured = response.configured === true;
                    agenda.events = Array.isArray(response.events) ? response.events : [];
                    agenda.calendars = Array.isArray(response.calendars) ? response.calendars : [];
                    agenda.errorMessage = "";
                } catch (error) {
                    agenda.errorMessage = "Could not read calendar events";
                }
            } else {
                agenda.errorMessage = "Calendar source unavailable";
            }

            if (agenda.refreshPending) {
                agenda.refreshPending = false;
                agenda.refresh();
            }
        }
    }
}
