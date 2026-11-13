pragma ComponentBehavior: Bound
import QtQuick
import "DesktopIcons.js" as DesktopIcons
import Quickshell
import QtCore

Item {
    id: panel

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    signal keyboardRequested
    signal revealSelection(real top, real bottom)

    property bool open: false
    property int selectedIndex: 0
    property int preferredColumn: 0
    readonly property int gridColumns: width < 340 ? 1 : width < 510 ? 2 : 3
    onGridColumnsChanged: preferredColumn = selectedIndex % gridColumns
    property string armedAction: ""
    property string statusText: ""
    property bool statusError: false

    Settings {
        id: preferences
        location: "file://" + (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/linux-desktop/preferences.ini"
        category: "Session"
        property bool restoreWindowsOnExit: panel.runtime.restoreWindowsOnExit
        property string preferenceSource: ""
    }
    readonly property bool restoreWindowsOnExit: preferences.preferenceSource === "default" ? runtime.restoreWindowsOnExit : preferences.restoreWindowsOnExit

    Component.onCompleted: {
        if (preferences.preferenceSource !== "")
            return;
        // Preserve explicitly stored values from older settings files.
        preferences.preferenceSource = preferences.value("restoreWindowsOnExit", null) === null ? "default" : "user";
        preferences.setValue("preferenceSource", preferences.preferenceSource);
        preferences.sync();
    }

    function resetToDeclared(): void {
        preferences.preferenceSource = "default";
        preferences.setValue("preferenceSource", "default");
        preferences.sync();
    }

    function toggleRestore(): void {
        preferences.restoreWindowsOnExit = !restoreWindowsOnExit;
        preferences.setValue("restoreWindowsOnExit", preferences.restoreWindowsOnExit);
        preferences.preferenceSource = "user";
        preferences.setValue("preferenceSource", "user");
        preferences.sync();
        statusText = restoreWindowsOnExit ? "WINDOW RESTORATION ENABLED" : "FRESH SESSION ENABLED";
        statusError = false;
    }

    readonly property var entries: [
        {
            id: "lock",
            shortcut: "Q",
            accentRole: "connectivity",
            label: "Lock",
            icon: "",
            description: "Secure the current Wayland session",
            destructive: false
        },
        {
            id: "suspend",
            shortcut: "W",
            accentRole: "media",
            label: "Suspend",
            icon: "󰤄",
            description: "Suspend the machine until resumed",
            destructive: true
        },
        {
            id: "logout",
            shortcut: "E",
            accentRole: "capture",
            label: "Log out",
            icon: "󰍃",
            description: "Exit the current Hyprland session",
            destructive: true
        },
        {
            id: "reboot",
            shortcut: "A",
            accentRole: "resources",
            label: "Reboot",
            icon: "󰜉",
            description: "Restart the machine",
            destructive: true
        },
        {
            id: "poweroff",
            shortcut: "S",
            accentRole: "attention",
            label: "Power off",
            icon: "󰐥",
            description: "Shut the machine down",
            destructive: true
        },
        {
            id: "restore",
            shortcut: "D",
            accentRole: "resources",
            label: "Restore windows",
            icon: "󰑓",
            description: "Restore open windows after logout, reboot or shutdown",
            destructive: false
        }
    ]

    readonly property string actionShortcutLegend: entries.slice(0, 3).map(entry => entry.shortcut).join("/") + " · " + entries.slice(3).map(entry => entry.shortcut).join("/")

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
            const rowStart = Math.floor(selectedIndex / gridColumns) * gridColumns;
            const rowEnd = Math.min(entries.length - 1, rowStart + gridColumns - 1);
            moveSelection(Math.max(rowStart, Math.min(rowEnd, selectedIndex + horizontal)) - selectedIndex);
        } else if (vertical !== 0) {
            const targetRow = Math.floor(selectedIndex / gridColumns) + vertical;
            const lastRow = Math.floor((entries.length - 1) / gridColumns);
            if (targetRow >= 0 && targetRow <= lastRow) {
                const target = Math.min(entries.length - 1, targetRow * gridColumns + preferredColumn);
                const column = preferredColumn;
                moveSelection(target - selectedIndex);
                // Keep the intended column for the return trip across a
                // shorter row when navigating back upwards.
                preferredColumn = column;
            }
        }
    }

    function moveSelection(delta: int): void {
        selectedIndex = Math.max(0, Math.min(entries.length - 1, selectedIndex + delta));
        preferredColumn = selectedIndex % gridColumns;
        armTimer.stop();
        armedAction = "";
        statusText = "";
        statusError = false;
        if (open) {
            const row = Math.floor(selectedIndex / gridColumns);
            const top = buttonGrid.y + row * (155 + buttonGrid.spacing);
            revealSelection(top, top + 155);
        }
    }

    function cancelConfirmation(): void {
        armTimer.stop();
        armedAction = "";
        statusText = "";
        statusError = false;
    }

    function execute(entry): void {
        if (!entry)
            return;

        if (entry.id === "restore") {
            toggleRestore();
            return;
        }

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

        Quickshell.execDetached([runtime.sessionCommand, entry.id, restoreWindowsOnExit ? "restore" : "fresh"]);
        closeView();
    }

    function activateShortcut(key: int): bool {
        const shortcut = String.fromCharCode(key);
        const index = entries.findIndex(entry => entry.shortcut === shortcut);
        if (index < 0)
            return false;
        activateIndex(index);
        return true;
    }

    function activateIndex(index: int): void {
        if (index < 0 || index >= entries.length)
            return;
        if (selectedIndex !== index)
            moveSelection(index - selectedIndex);
        activateSelected();
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

    implicitWidth: 3 * 154 + 2 * theme.spacing3 + theme.spacing5 * 2
    implicitHeight: header.implicitHeight + buttonGrid.implicitHeight + footer.implicitHeight + theme.spacing5 * 3

    DetailHero {
        id: header
        quiet: true
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        motion: panel.motion
        glyph: panel.armedAction.length > 0 ? "!" : DesktopIcons.glyphFor("session")
        glyphFont: "Symbols Nerd Font"
        glyphColor: panel.armedAction.length > 0 ? panel.theme.warning : panel.theme.roleColor("resources")
        eyebrow: "Device / secure session"
        title: "Power & session"
        detail: panel.armedAction.length > 0 ? "Confirm within 5 seconds" : panel.selectedEntry().id === "restore" ? (panel.restoreWindowsOnExit ? "Reopen windows after leaving the session" : "Start fresh after leaving the session") : panel.selectedEntry().description
    }

    Column {
        id: buttonGrid
        width: Math.min(parent.width, panel.gridColumns * 154 + (panel.gridColumns - 1) * panel.theme.spacing3)
        anchors {
            top: header.bottom
            topMargin: panel.theme.spacing5
            horizontalCenter: parent.horizontalCenter
        }
        spacing: panel.theme.spacing3

        Repeater {
            model: Math.ceil(panel.entries.length / panel.gridColumns)

            delegate: Row {
                id: actionRow
                required property int index
                readonly property int rowCount: Math.min(panel.gridColumns, panel.entries.length - index * panel.gridColumns)
                width: Math.min(buttonGrid.width, rowCount * 154 + (rowCount - 1) * panel.theme.spacing3)
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: panel.theme.spacing3

                Repeater {
                    model: panel.entries.slice(actionRow.index * panel.gridColumns, (actionRow.index + 1) * panel.gridColumns)

                    delegate: SessionActionButton {
                        required property var modelData
                        readonly property int actionIndex: panel.entries.findIndex(entry => entry.id === modelData.id)
                        width: Math.max(1, (actionRow.width - actionRow.spacing * (actionRow.rowCount - 1)) / actionRow.rowCount)

                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion
                        icon: modelData.icon
                        lockGlyph: modelData.id === "lock"
                        shortcut: modelData.shortcut
                        label: modelData.label
                        accentColor: panel.theme.roleColor(modelData.accentRole)
                        active: modelData.id === "restore" && panel.restoreWindowsOnExit
                        selected: panel.selectedIndex === actionIndex
                        armed: panel.armedAction === modelData.id

                        onHovered: {
                            if (panel.selectedIndex !== actionIndex)
                                panel.moveSelection(actionIndex - panel.selectedIndex);
                        }
                        onActivated: {
                            if (panel.selectedIndex !== actionIndex)
                                panel.moveSelection(actionIndex - panel.selectedIndex);
                            panel.activateSelected();
                            panel.keyboardRequested();
                        }
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
            color: panel.theme.readableRoleColor(panel.statusError ? "critical" : "warning")
            horizontalAlignment: Text.AlignHCenter
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(11)
            font.weight: Font.DemiBold
        }

        // Direct action keycaps already live on their tiles. Centre only the
        // navigation and selected-action hints; wrap at narrow panel widths.
        Item {
            id: hintRegion
            width: buttonGrid.width
            height: hintFlow.height
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property real naturalWidth: moveHint.implicitWidth + actionHint.implicitWidth + panel.theme.spacing3

            Flow {
                id: hintFlow
                width: Math.min(parent.width, hintRegion.naturalWidth)
                height: childrenRect.height
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: panel.theme.spacing3

                KeyHint {
                    id: moveHint
                    runtime: panel.runtime
                    theme: panel.theme
                    shortcut: "HJKL"
                    label: "Move"
                    compact: true
                }

                KeyHint {
                    id: actionHint
                    runtime: panel.runtime
                    theme: panel.theme
                    shortcut: "ENTER"
                    label: panel.armedAction.length > 0 ? "Confirm" : "Activate"
                    compact: true
                }
            }
        }
    }
}
