pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

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
    readonly property int gridColumns: 1
    onGridColumnsChanged: preferredColumn = selectedIndex % gridColumns
    property string armedAction: ""
    property string statusText: ""
    property bool statusError: false

    readonly property var entries: [
        {
            id: "lock",
            accentRole: "connectivity",
            label: "Lock",
            icon: "󰌾",
            description: "Secure the current Wayland session",
            destructive: false
        },
        {
            id: "suspend",
            accentRole: "media",
            label: "Suspend",
            icon: "󰤄",
            description: "Suspend the machine until resumed",
            destructive: true
        },
        {
            id: "logout",
            accentRole: "capture",
            label: "Log out",
            icon: "󰍃",
            description: "Exit the current Hyprland session",
            destructive: true
        },
        {
            id: "reboot",
            accentRole: "resources",
            label: "Reboot",
            icon: "󰜉",
            description: "Restart the machine",
            destructive: true
        },
        {
            id: "poweroff",
            accentRole: "attention",
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
            const top = buttonGrid.y + row * (92 + buttonGrid.spacing);
            revealSelection(top, top + 92);
        }
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

    DetailHero {
        id: header
        quiet: true
        width: parent.width
        runtime: panel.runtime
        theme: panel.theme
        motion: panel.motion
        glyph: panel.armedAction.length > 0 ? "!" : "⏻"
        glyphColor: panel.armedAction.length > 0 ? panel.theme.warning : panel.theme.roleColor("resources")
        eyebrow: "Device / secure session"
        title: "Power & session"
        detail: panel.armedAction.length > 0 ? "Confirm within 5 seconds" : panel.selectedEntry().description
    }

    Column {
        id: buttonGrid
        anchors {
            top: header.bottom
            topMargin: panel.theme.spacing5
            horizontalCenter: parent.horizontalCenter
        }
        spacing: panel.theme.spacing3

        Repeater {
            model: panel.entries
            delegate: Item {
                id: entryRow
                required property var modelData
                required property int index
                width: Math.max(1, panel.width - panel.theme.spacing4)
                height: 92
                readonly property bool chosen: panel.selectedIndex === index
                readonly property color role: panel.theme.roleColor(modelData.accentRole)

                ShellSurface {
                    id: entrySurface
                    anchors.fill: parent
                    theme: panel.theme
                    motion: panel.motion
                    glassAllowed: false
                    surfaceLayer: ShellSurface.Control
                    cornerRadius: entryRow.chosen ? panel.theme.radiusPanel : panel.theme.radiusMedium
                    fillColor: entryRow.chosen ? panel.theme.blend(panel.theme.materialPrimaryContainer, entryRow.role, 0.18) : panel.theme.materialContainer
                    borderColor: panel.armedAction === entryRow.modelData.id ? panel.theme.warning : entryRow.chosen ? entryRow.role : panel.theme.subtleBorder
                    borderWidth: panel.theme.borderThin
                    Behavior on cornerRadius {
                        Anim {
                            motion: panel.motion
                            type: Anim.FastSpatial
                        }
                    }
                    ShellSurface {
                        x: panel.theme.spacing3
                        anchors.verticalCenter: parent.verticalCenter
                        width: 56
                        height: 56
                        theme: panel.theme
                        motion: panel.motion
                        glassAllowed: false
                        surfaceLayer: ShellSurface.Control
                        cornerRadius: entryRow.chosen ? 28 : panel.theme.radiusSmall
                        fillColor: entryRow.chosen ? entryRow.role : panel.theme.materialContainerHigh
                        Text {
                            anchors.centerIn: parent
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: panel.theme.fontSize(29)
                            color: entryRow.chosen ? panel.theme.background : entryRow.role
                            text: entryRow.modelData.icon
                        }
                    }
                    Column {
                        x: 86
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 155
                        spacing: 4
                        Text {
                            text: entryRow.modelData.label
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(17)
                            font.weight: Font.Bold
                            color: panel.theme.textStrong
                        }
                        Text {
                            text: entryRow.modelData.description
                            width: parent.width
                            elide: Text.ElideRight
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(11)
                            color: panel.theme.textMuted
                        }
                    }
                    KeyHint {
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: panel.theme.spacing4
                        }
                        shortcut: "ENTER"
                        compact: true
                        emphasized: entryRow.chosen
                        runtime: panel.runtime
                        theme: panel.theme
                    }
                }
                StateLayer {
                    theme: panel.theme
                    motion: panel.motion
                    cornerRadius: entrySurface.cornerRadius
                    onActivated: {
                        panel.moveSelection(entryRow.index - panel.selectedIndex);
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
            color: panel.theme.readableRoleColor(panel.statusError ? "critical" : "warning")
            horizontalAlignment: Text.AlignHCenter
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(11)
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: "H/J/K/L · NAVIGATE   ENTER · ARM/RUN   ESC · BACK"
            color: panel.theme.textMuted
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontKeyHint
        }
    }
}
