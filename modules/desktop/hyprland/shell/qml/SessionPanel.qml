import QtQuick
import Quickshell

Item {
    id: panel

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

    signal keyboardRequested()

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
        spacing: theme.spacing1

        Text {
            text: "SESSION // LOCAL"
            color: theme.accent
            font.family: runtime.fontMono
            font.pixelSize: theme.fontSubpanelEyebrow
            font.weight: Font.DemiBold
            font.letterSpacing: 1.6
        }

        Text {
            text: "Power & session"
            color: theme.textStrong
            font.family: runtime.fontSans
            font.pixelSize: theme.fontSubpanelTitle
            font.weight: Font.DemiBold
        }

        Text {
            text: armedAction.length > 0
                ? "CONFIRMATION ARMED // 5 SECOND WINDOW"
                : "SELECT AN ACTION"
            color: armedAction.length > 0 ? theme.warning : theme.textMuted
            font.family: runtime.fontMono
            font.pixelSize: theme.fontSize(9)
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
            topMargin: theme.spacing4
            bottomMargin: theme.spacing3
        }

        model: panel.entries
        spacing: theme.spacing2
        clip: true
        currentIndex: panel.selectedIndex
        boundsBehavior: Flickable.StopAtBounds

        delegate: SquircleSurface {
            id: actionRow

            required property var modelData
            required property int index

            width: ListView.view.width
            height: 66
            exponent: theme.squircleExponent
            cornerRadius: theme.radiusMedium
            fillColor: index === panel.selectedIndex ? theme.focusFill : theme.background
            borderColor: modelData.id === panel.armedAction
                ? theme.warning
                : (index === panel.selectedIndex ? theme.accent : theme.outline)
            borderWidth: modelData.id === panel.armedAction || index === panel.selectedIndex
                ? theme.borderFocus
                : theme.borderThin

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
                    margins: theme.spacing3
                }
                spacing: theme.spacing3

                Column {
                    width: parent.width - actionState.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        width: parent.width
                        text: modelData.label
                        color: modelData.id === panel.armedAction ? theme.warning : theme.textStrong
                        font.family: runtime.fontSans
                        font.pixelSize: theme.fontSize(14)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: modelData.description
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(8)
                        elide: Text.ElideRight
                    }
                }

                Text {
                    id: actionState
                    width: 112
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: modelData.id === panel.armedAction
                        ? "CONFIRM"
                        : (modelData.destructive ? "ARM" : "RUN")
                    color: modelData.id === panel.armedAction ? theme.warning : theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(9)
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
        spacing: theme.spacing2

        Text {
            width: parent.width
            visible: statusText.length > 0
            text: statusText
            color: statusError ? theme.critical : theme.warning
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            font.family: runtime.fontMono
            font.pixelSize: theme.fontSize(8)
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
        }

        Row {
            anchors.right: parent.right
            spacing: theme.spacing4

            Text {
                text: "↑/↓  SELECT"
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(8)
                font.letterSpacing: 0.8
            }

            Text {
                text: armedAction.length > 0 ? "ENTER  CONFIRM" : "ENTER  ARM/RUN"
                color: armedAction.length > 0 ? theme.warning : theme.accent
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(8)
                font.letterSpacing: 0.8
            }

            Text {
                text: "ESC  BACK"
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(8)
                font.letterSpacing: 0.8
            }
        }
    }
}
