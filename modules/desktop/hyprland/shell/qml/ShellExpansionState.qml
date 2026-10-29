import QtQuick

QtObject {
    id: root

    property string currentName: ""
    property string currentView: ""
    property string backDestination: ""
    property bool hasCurrent: false
    property var screen: null
    property real originCenter: 0
    property real originWidth: 0
    property real originHeight: 0

    function show(name: string, targetScreen: var, center: real, width: real, height: real, view: string): void {
        const requestedView = view || "";
        const fromControls = hasCurrent && currentName === "system" && (currentView === "" || currentView === "controls" || backDestination === "controls");
        const toControls = fromControls && (name === "media" || name === "system" && requestedView !== "" && requestedView !== "controls");
        const toCalendar = hasCurrent && currentName === "calendar" && name === "weather";
        backDestination = toControls ? "controls" : toCalendar ? "calendar" : "";
        currentName = name;
        currentView = name === "system" ? requestedView : "";
        screen = targetScreen;
        originCenter = center;
        originWidth = width;
        originHeight = height;
        hasCurrent = true;
    }

    // Detail navigation from a visible Controls page must update the same
    // history as opening a detail through a global shortcut.
    function enterDetail(view: string): void {
        if (!hasCurrent || currentName !== "system")
            return;
        const fromControls = currentView === "" || currentView === "controls" || backDestination === "controls";
        backDestination = fromControls ? "controls" : "";
        currentView = view;
    }

    function back(): void {
        const destination = backDestination;
        if (!destination) {
            close();
            return;
        }
        backDestination = "";
        currentName = destination === "controls" ? "system" : destination;
        currentView = destination === "controls" ? "controls" : "";
    }

    function toggle(name: string, targetScreen: var, center: real, width: real, height: real, view: string): void {
        const requestedView = view || "";
        if (hasCurrent && currentName === name && screen === targetScreen && requestedView.length === 0) {
            close();
            return;
        }

        show(name, targetScreen, center, width, height, requestedView);
    }

    function navigate(name: string): void {
        backDestination = "";
        currentView = "";
        currentName = name;
    }

    function close(): void {
        hasCurrent = false;
        backDestination = "";
    }

    function finishClose(): void {
        if (hasCurrent)
            return;

        currentName = "";
        currentView = "";
        screen = null;
        originCenter = 0;
        originWidth = 0;
        originHeight = 0;
    }
}
