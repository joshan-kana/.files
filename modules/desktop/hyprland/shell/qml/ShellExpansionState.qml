import QtQuick

QtObject {
    id: root

    property string currentName: ""
    property string currentView: ""
    property bool hasCurrent: false
    property var screen: null
    property real originCenter: 0
    property real originWidth: 0
    property real originHeight: 0

    function show(name: string, targetScreen: var, center: real, width: real, height: real, view: string): void {
        currentName = name;
        currentView = view || "";
        screen = targetScreen;
        originCenter = center;
        originWidth = width;
        originHeight = height;
        hasCurrent = true;
    }

    function toggle(name: string, targetScreen: var, center: real, width: real, height: real, view: string): void {
        const requestedView = view || "";
        if (hasCurrent && currentName === name && screen === targetScreen && requestedView.length === 0) {
            close();
            return;
        }

        show(name, targetScreen, center, width, height, requestedView);
    }

    function close(): void {
        hasCurrent = false;
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
