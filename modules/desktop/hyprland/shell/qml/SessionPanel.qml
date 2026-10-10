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
    property int preferredColumn: 0
    property string armedAction: ""
    property string statusText: ""
    property bool statusError: false

    readonly property var entries: [
        {
            id: "lock",
            label: "Lock",
            icon: "󰌾",
            description: "Secure the current Wayland session",
            destructive: false
        },
        {
            id: "suspend",
            label: "Suspend",
            icon: "󰤄",
            description: "Suspend the machine until resumed",
            destructive: true
        },
        {
            id: "logout",
            label: "Log out",
            icon: "󰍃",
            description: "Exit the current Hyprland session",
            destructive: true
        },
        {
            id: "reboot",
            label: "Reboot",
            icon: "󰜉",
            description: "Restart the machine",
            destructive: true
        },
        {
            id: "poweroff",
            label: "Power off",
            icon: "󰐥",
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
        preferredColumn = 0;
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

    function moveGrid(horizontal: int, vertical: int): void {
        if (horizontal !== 0) {
            const rowStart = Math.floor(selectedIndex / 3) * 3;
            const rowEnd = Math.min(entries.length - 1, rowStart + 2);
            moveSelection(Math.max(rowStart, Math.min(rowEnd, selectedIndex + horizontal)) - selectedIndex);
        } else if (vertical !== 0) {
            const targetRow = Math.floor(selectedIndex / 3) + vertical;
            const lastRow = Math.floor((entries.length - 1) / 3);
            if (targetRow >= 0 && targetRow <= lastRow) {
                const target = Math.min(entries.length - 1, targetRow * 3 + preferredColumn);
                const column = preferredColumn;
                moveSelection(target - selectedIndex);
                // Keep the intended column for the return trip across a
                // shorter row (Log out -> Power off -> Log out).
                preferredColumn = column;
            }
        }
    }

    function moveSelection(delta: int): void {
        selectedIndex = Math.max(0, Math.min(entries.length - 1, selectedIndex + delta));
        preferredColumn = selectedIndex % 3;
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

    implicitHeight: header.implicitHeight + buttonGrid.implicitHeight + footer.implicitHeight + theme.spacing5 * 3

    Column {
        id: header
        width: parent.width
        spacing: panel.theme.spacing1

        Text {
            text: "SESSION"
            color: panel.theme.accent
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(11)
            font.weight: Font.DemiBold
        }

        Text {
            text: "Power & session"
            color: panel.theme.textStrong
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSubpanelTitle
            font.weight: Font.DemiBold
        }

        Text {
            text: panel.armedAction.length > 0 ? "Confirm within 5 seconds" : panel.selectedEntry().description
            color: panel.armedAction.length > 0 ? panel.theme.warning : panel.theme.textMuted
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(10)
        }
    }

    Column {
        id: buttonGrid
        anchors {
            top: header.bottom
            topMargin: panel.theme.spacing5
            horizontalCenter: parent.horizontalCenter
        }
        spacing: panel.theme.spacing3

        Row {
            id: firstRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: panel.theme.spacing3

            Repeater {
                model: panel.entries.slice(0, 3)
                delegate: SessionActionButton {
                    required property int index
                    required property var modelData
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    icon: modelData.icon
                    label: modelData.label
                    selected: panel.selectedIndex === index
                    armed: panel.armedAction === modelData.id
                    onHovered: {
                        if (panel.selectedIndex !== index)
                            panel.moveSelection(index - panel.selectedIndex);
                    }
                    onActivated: {
                        if (panel.selectedIndex !== index)
                            panel.moveSelection(index - panel.selectedIndex);
                        panel.activateSelected();
                        panel.keyboardRequested();
                    }
                }
            }
        }

        Row {
            id: lastRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: panel.theme.spacing3

            Repeater {
                model: panel.entries.slice(3)
                delegate: SessionActionButton {
                    required property int index
                    required property var modelData
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    icon: modelData.icon
                    label: modelData.label
                    selected: panel.selectedIndex === index + 3
                    armed: panel.armedAction === modelData.id
                    onHovered: {
                        if (panel.selectedIndex !== index + 3)
                            panel.moveSelection(index + 3 - panel.selectedIndex);
                    }
                    onActivated: {
                        if (panel.selectedIndex !== index + 3)
                            panel.moveSelection(index + 3 - panel.selectedIndex);
                        panel.activateSelected();
                        panel.keyboardRequested();
                    }
                }
            }
        }
    }

    Column {
        id: footer
        anchors {
            left: parent.left
            right: parent.right
            top: buttonGrid.bottom
            topMargin: panel.theme.spacing4
        }
        spacing: panel.theme.spacing2

        Text {
            width: parent.width
            visible: panel.statusText.length > 0
            text: panel.statusText
            color: panel.statusError ? panel.theme.critical : panel.theme.warning
            horizontalAlignment: Text.AlignHCenter
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(11)
            font.weight: Font.DemiBold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "H/J/K/L · NAVIGATE   ENTER · ARM/RUN   ESC · BACK"
            color: panel.theme.textMuted
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(9)
        }
    }
}
