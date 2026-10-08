pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Item {
    id: panel

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    signal keyboardRequested

    property bool open: false
    property int selectedIndex: 0
    property string armedAction: ""
    property string statusText: ""
    property bool statusError: false

    readonly property var entries: [
        {
            id: "lock",
            label: "Lock",
            description: "Secure the current Wayland session",
            destructive: false
        },
        {
            id: "suspend",
            label: "Suspend",
            description: "Suspend the machine until resumed",
            destructive: true
        },
        {
            id: "logout",
            label: "Log out",
            description: "Exit the current Hyprland session",
            destructive: true
        },
        {
            id: "reboot",
            label: "Reboot",
            description: "Restart the machine",
            destructive: true
        },
        {
            id: "poweroff",
            label: "Power off",
            description: "Shut the machine down",
            destructive: true
        }
    ]

    visible: open

    Timer {
        id: armTimer
        interval: 5000
        repeat: false

        onTriggered: {
            panel.armedAction = "";
            panel.statusText = "";
            panel.statusError = false;
        }
    }

    function selectedEntry(): var {
        if (entries.length === 0)
            return null;

        return entries[Math.max(0, Math.min(selectedIndex, entries.length - 1))];
    }

    function openView(): void {
        armTimer.stop();
        open = true;
        selectedIndex = 0;
        armedAction = "";
        statusText = "";
        statusError = false;
        keyboardRequested();
    }

    function closeView(): void {
        armTimer.stop();
        open = false;
        armedAction = "";
        statusText = "";
        statusError = false;
        keyboardRequested();
    }

    function moveHalfPage(direction: int): void {
        const rowHeight = actionList.currentItem ? actionList.currentItem.height + actionList.spacing : 64;
        const rows = Math.max(1, Math.floor(actionList.height / Math.max(1, rowHeight) / 2));
        moveSelection(direction * rows);
    }

    function moveSelection(delta: int): void {
        selectedIndex = Math.max(0, Math.min(entries.length - 1, selectedIndex + delta));
        armTimer.stop();
        armedAction = "";
        statusText = "";
        statusError = false;
    }

    function execute(entry): void {
        if (!entry)
            return;

        if (entry.id === "lock") {
            if (runtime.lockSession.length === 0) {
                statusText = "LOCK SERVICE UNAVAILABLE";
                statusError = true;
                return;
            }

            Quickshell.execDetached([runtime.lockSession]);
            closeView();
            return;
        }

        if (runtime.sessionCommand.length === 0) {
            statusText = "SESSION BACKEND UNAVAILABLE";
            statusError = true;
            return;
        }

        Quickshell.execDetached([runtime.sessionCommand, entry.id]);
        closeView();
    }

    function activateSelected(): void {
        const entry = selectedEntry();
        if (!entry)
            return;

        if (!entry.destructive) {
            execute(entry);
            return;
        }

        if (armedAction === entry.id) {
            armTimer.stop();
            armedAction = "";
            execute(entry);
            return;
        }

        armedAction = entry.id;
        statusText = "CONFIRM // " + entry.label.toUpperCase();
        statusError = false;
        armTimer.restart();
    }

    Column {
        id: header

        width: parent.width
        spacing: panel.theme.spacing1

        Text {
            text: "Session"
            color: panel.theme.accent
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(11)
            font.weight: Font.Medium
        }

        Text {
            text: "Power & session"
            color: panel.theme.textStrong
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSubpanelTitle
            font.weight: Font.DemiBold
        }

        Text {
            text: panel.armedAction.length > 0 ? "Confirm within 5 seconds" : "Choose an action"
            color: panel.armedAction.length > 0 ? panel.theme.warning : panel.theme.textMuted
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(9)
            font.letterSpacing: 0.8
        }
    }

    ListView {
        id: actionList

        anchors {
            top: header.bottom
            right: parent.right
            bottom: footer.top
            left: parent.left
            topMargin: panel.theme.spacing4
            bottomMargin: panel.theme.spacing3
        }

        model: panel.entries
        spacing: panel.theme.spacing2
        clip: true
        currentIndex: panel.selectedIndex
        boundsBehavior: Flickable.StopAtBounds

        delegate: ShellSurface {
            id: actionRow

            required property var modelData
            required property int index

            width: ListView.view.width
            height: 66
            theme: panel.theme
            motion: panel.motion
            surfaceLayer: ShellSurface.Control
            selected: index === panel.selectedIndex
            cornerRadius: theme.radiusMedium

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    panel.selectedIndex = actionRow.index;
                    panel.activateSelected();
                    panel.keyboardRequested();
                }
            }

            Row {
                anchors {
                    fill: parent
                    margins: panel.theme.spacing3
                }
                spacing: panel.theme.spacing3

                Column {
                    width: parent.width - actionState.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        width: parent.width
                        text: actionRow.modelData.label
                        color: actionRow.modelData.id === panel.armedAction ? panel.theme.warning : panel.theme.textStrong
                        font.family: panel.runtime.fontMono
                        font.pixelSize: panel.theme.fontSize(14)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: actionRow.modelData.description
                        color: panel.theme.textMuted
                        font.family: panel.runtime.fontMono
                        font.pixelSize: panel.theme.fontSize(8)
                        elide: Text.ElideRight
                    }
                }

                Text {
                    id: actionState
                    width: 112
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: actionRow.modelData.id === panel.armedAction ? "CONFIRM" : (actionRow.modelData.destructive ? "ARM" : "RUN")
                    color: actionRow.modelData.id === panel.armedAction ? panel.theme.warning : panel.theme.accent
                    font.family: panel.runtime.fontMono
                    font.pixelSize: panel.theme.fontSize(9)
                    font.weight: Font.DemiBold
                }
            }
        }

        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
    }

    Column {
        id: footer

        anchors {
            right: parent.right
            bottom: parent.bottom
            left: parent.left
        }
        spacing: panel.theme.spacing2

        Text {
            width: parent.width
            visible: panel.statusText.length > 0
            text: panel.statusText
            color: panel.statusError ? panel.theme.critical : panel.theme.warning
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(8)
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
        }

        Row {
            anchors.right: parent.right
            spacing: panel.theme.spacing4

            Text {
                text: "↑/↓  SELECT"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(8)
                font.letterSpacing: 0.8
            }

            Text {
                text: panel.armedAction.length > 0 ? "ENTER  CONFIRM" : "ENTER  ARM/RUN"
                color: panel.armedAction.length > 0 ? panel.theme.warning : panel.theme.accent
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(8)
                font.letterSpacing: 0.8
            }

            Text {
                text: "ESC  BACK"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(8)
                font.letterSpacing: 0.8
            }
        }
    }
}
