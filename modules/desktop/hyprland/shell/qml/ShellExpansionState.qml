import QtQuick

QtObject {
    id: root

    property string currentName: ""
    property bool hasCurrent: false
    property var screen: null
    property real originCenter: 0
    property real originWidth: 0
    property real originHeight: 0

    function show(name: string, targetScreen: var, center: real, width: real, height: real): void {
        currentName = name;
        screen = targetScreen;
        originCenter = center;
        originWidth = width;
        originHeight = height;
        hasCurrent = true;
    }

    function toggle(name: string, targetScreen: var, center: real, width: real, height: real): void {
        if (hasCurrent && currentName === name && screen === targetScreen) {
            close();
            return;
        }

        show(name, targetScreen, center, width, height);
    }

    function close(): void {
        hasCurrent = false;
    }

    function finishClose(): void {
        if (hasCurrent)
            return;

        currentName = "";
        screen = null;
        originCenter = 0;
        originWidth = 0;
        originHeight = 0;
    }
}
