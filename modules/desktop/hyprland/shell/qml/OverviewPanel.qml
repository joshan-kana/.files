pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: overview

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool open: false
    property bool closing: false
    property int selectedIndex: 0
    property string selectedAddress: ""
    property bool moveMode: false
    property bool movePending: false
    property int destinationWorkspace: 1
    property int pendingWorkspace: 0
    property var moveTarget: null
    property string statusText: ""
    property var actionTarget: null
    property bool actionPending: false
    property string actionKind: ""
    property bool actionExpected: false
    readonly property var chosenWindow: windows.find(toplevel => windowAddress(toplevel) === selectedAddress) || (selectedIndex >= 0 && selectedIndex < windows.length ? windows[selectedIndex] : null)
    readonly property bool chosenFloating: !!(chosenWindow && (chosenWindow.lastIpcObject || {}).floating)
    readonly property bool chosenPinned: !!(chosenWindow && (chosenWindow.lastIpcObject || {}).pinned)

    readonly property var windows: Hyprland.toplevels.values.filter(toplevel => {
        if (!toplevel || !toplevel.workspace || toplevel.workspace.id <= 0)
            return false;
        // Some compositor helper surfaces are exposed as toplevels without an app identity.
        const info = toplevel.lastIpcObject || {};
        return Boolean(info.class || (toplevel.wayland && toplevel.wayland.appId));
    }).sort((left, right) => left.workspace.id - right.workspace.id || left.title.localeCompare(right.title))
    readonly property int focusedWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    visible: open || closing
    focusable: open
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }
    WlrLayershell.namespace: "linux-desktop-overview"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function windowAddress(toplevel: var): string {
        return toplevel ? String((toplevel.lastIpcObject || {}).address || "") : "";
    }

    function chooseIndex(index: int): void {
        if (windows.length === 0) {
            selectedIndex = 0;
            selectedAddress = "";
            return;
        }
        const next = Math.max(0, Math.min(windows.length - 1, index));
        selectedAddress = windowAddress(windows[next]);
        selectedIndex = next;
    }

    onWindowsChanged: {
        const existingIndex = windows.findIndex(toplevel => windowAddress(toplevel) === selectedAddress);
        if (existingIndex >= 0)
            selectedIndex = existingIndex;
        else
            chooseIndex(selectedIndex);
        verifyMove();
    }

    Connections {
        target: overview.actionTarget
        ignoreUnknownSignals: true
        function onLastIpcObjectChanged() {
            overview.verifyWindowAction();
        }
    }

    Timer {
        // Only refresh the relevant compositor-owned state during a requested
        // action. Quickshell does not automatically update lastIpcObject for
        // floating/pinned changes; no idle/background polling is introduced.
        interval: 180
        repeat: true
        running: overview.actionPending
        onTriggered: Hyprland.refreshToplevels()
    }
    Timer {
        id: actionTimeout
        interval: 2100
        onTriggered: {
            if (!overview.actionPending)
                return;
            overview.verifyWindowAction();
            if (overview.actionPending) {
                overview.actionPending = false;
                overview.actionTarget = null;
                overview.statusText = "WINDOW ACTION NOT CONFIRMED";
                overviewFeedback.restart();
            }
        }
    }

    function verifyWindowAction(): void {
        if (!actionPending || !actionTarget)
            return;
        const info = actionTarget.lastIpcObject || {};
        if (Boolean(actionKind === "float" ? info.floating : info.pinned) !== actionExpected)
            return;
        actionPending = false;
        actionTarget = null;
        actionTimeout.stop();
        statusText = actionKind === "float" ? (actionExpected ? "FLOATING · CONFIRMED" : "TILED · CONFIRMED") : (actionExpected ? "PINNED · CONFIRMED" : "UNPINNED · CONFIRMED");
        overviewFeedback.restart();
    }

    Connections {
        target: overview.moveTarget
        ignoreUnknownSignals: true
        function onWorkspaceChanged() {
            overview.verifyMove();
        }
    }

    Timer {
        id: moveTimeout
        interval: 2500
        onTriggered: {
            if (!overview.movePending)
                return;
            overview.verifyMove();
            if (overview.movePending) {
                overview.movePending = false;
                overview.statusText = "MOVE NOT CONFIRMED · RETRY OR ESC CANCEL";
                overviewFeedback.restart();
            }
        }
    }

    Timer {
        id: overviewFeedback
        interval: 2300
        onTriggered: {
            if (!overview.movePending)
                overview.statusText = "";
        }
    }

    function verifyMove(): void {
        if (!movePending || !moveTarget || !moveTarget.workspace)
            return;
        if (moveTarget.workspace.id !== pendingWorkspace)
            return;
        movePending = false;
        moveMode = false;
        moveTarget = null;
        statusText = "MOVED · WORKSPACE " + pendingWorkspace;
        moveTimeout.stop();
        overviewFeedback.restart();
    }

    function startMove(index: int): void {
        const target = windows[index];
        if (!target || movePending)
            return;
        const addr = String((target.lastIpcObject || {}).address || "");
        if (!/^0x[0-9a-f]+$/i.test(addr)) {
            statusText = "WINDOW MOVE UNAVAILABLE · NO COMPOSITOR ADDRESS";
            overviewFeedback.restart();
            return;
        }
        chooseIndex(index);
        moveTarget = target;
        moveMode = true;
        destinationWorkspace = target.workspace ? Math.max(1, Math.min(10, target.workspace.id)) : focusedWorkspace;
        statusText = "MOVE WINDOW · CHOOSE DESTINATION";
    }

    function cancelMove(): void {
        if (movePending)
            return;
        moveMode = false;
        moveTarget = null;
        statusText = "";
    }

    function hoverDestination(item: var, x: real, y: real): int {
        const point = workspaceRow.mapFromItem(item, x, y);
        if (point.x < 0 || point.x > workspaceRow.width || point.y < 0 || point.y > workspaceRow.height)
            return 0;
        const section = workspaceRow.width / 10;
        const index = Math.max(0, Math.min(9, Math.floor(point.x / Math.max(1, section))));
        return index + 1;
    }

    function toggleWindowState(kind: string): void {
        if (moveMode || movePending || actionPending || !chosenWindow || (kind !== "float" && kind !== "pin"))
            return;
        const addr = String((chosenWindow.lastIpcObject || {}).address || "");
        if (!/^0x[0-9a-f]+$/i.test(addr)) {
            statusText = "WINDOW ACTION UNAVAILABLE · NO COMPOSITOR ADDRESS";
            overviewFeedback.restart();
            return;
        }
        if (kind === "pin" && !chosenFloating) {
            statusText = "PINNING REQUIRES A FLOATING WINDOW";
            overviewFeedback.restart();
            return;
        }
        actionTarget = chosenWindow;
        actionKind = kind;
        actionExpected = kind === "float" ? !chosenFloating : !chosenPinned;
        actionPending = true;
        statusText = kind === "float" ? "CHANGING WINDOW LAYOUT…" : "CHANGING PIN STATE…";
        Hyprland.dispatch('hl.dsp.window.' + kind + '({ action = "toggle", window = "address:' + addr + '" })');
        Qt.callLater(() => Hyprland.refreshToplevels());
        actionTimeout.restart();
    }

    function executeMove(workspace: int): void {
        if (!moveMode || !moveTarget || movePending || workspace < 1 || workspace > 10)
            return;
        const addr = String((moveTarget.lastIpcObject || {}).address || "");
        if (!/^0x[0-9a-f]+$/i.test(addr)) {
            cancelMove();
            statusText = "MOVE FAILED · WINDOW NO LONGER AVAILABLE";
            overviewFeedback.restart();
            return;
        }
        if (moveTarget.workspace && moveTarget.workspace.id === workspace) {
            moveMode = false;
            moveTarget = null;
            statusText = "ALREADY ON WORKSPACE " + workspace;
            overviewFeedback.restart();
            return;
        }
        pendingWorkspace = workspace;
        destinationWorkspace = workspace;
        statusText = "MOVING WINDOW · WORKSPACE " + workspace;
        movePending = true;
        Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + workspace + '", follow = false, window = "address:' + addr + '" })');
        verifyMove();
        if (movePending)
            moveTimeout.restart();
    }

    function show(): void {
        closeTimer.stop();
        open = true;
        closing = false;
        chooseIndex(Math.max(0, windows.findIndex(toplevel => toplevel.activated)));
        cancelMove();
        Hyprland.refreshToplevels();
        Qt.callLater(() => {
            if (open)
                keyboard.forceActiveFocus();
        });
    }
    function hide(): void {
        if (!open)
            return;

        // Preserve the Wayland surface until the longer spatial exit finishes.
        closing = motion.enabled;
        open = false;
        if (closing)
            closeTimer.restart();
    }
    function toggle(): void {
        if (open)
            hide();
        else
            show();
    }
    function focusWorkspace(id: int): void {
        if (id < 1 || id > 10)
            return;
        // Workspace browsing is internal to Overview; only explicit activation,
        // Escape or the canonical global toggle dismisses the surface.
        Hyprland.dispatch('hl.dsp.focus({ workspace = "' + id + '" })');
        const next = windows.findIndex(toplevel => toplevel.workspace && toplevel.workspace.id === id);
        if (next >= 0)
            chooseIndex(next);
    }
    function activateWindow(index: int): void {
        const toplevel = windows[index];
        if (!toplevel)
            return;
        hide();
        if (toplevel.wayland)
            toplevel.wayland.activate();
    }

    Timer {
        id: closeTimer
        interval: overview.motion.spatialNormal + (overview.motion.enabled ? 24 : 0)
        onTriggered: overview.closing = false
    }

    Rectangle {
        anchors.fill: parent
        color: overview.theme.scrim
        opacity: overview.open ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: overview.motion.fast
                easing.type: overview.open ? overview.motion.enterType : overview.motion.exitType
                easing.bezierCurve: overview.open ? overview.motion.enterCurve : overview.motion.exitCurve
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: overview.hide()
        }
    }

    ShellSurface {
        id: card
        anchors.centerIn: parent
        width: Math.min(overview.width - 100, 980)
        height: Math.min(overview.height - 120, Math.max(398, 294 + Math.min(4, Math.ceil(overview.windows.length / (width < 720 ? 2 : 3))) * 204))
        theme: overview.theme
        motion: overview.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusPanel
        scale: overview.open ? 1 : theme.panelClosedScale
        opacity: overview.open ? 1 : 0

        Behavior on scale {
            Anim {
                motion: overview.motion
                type: Anim.DefaultSpatial
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: overview.motion.fast
                easing.type: overview.open ? overview.motion.enterType : overview.motion.exitType
                easing.bezierCurve: overview.open ? overview.motion.enterCurve : overview.motion.exitCurve
            }
        }

        Column {
            anchors {
                fill: parent
                margins: overview.theme.spacing5
            }
            spacing: overview.theme.spacing4

            Column {
                width: parent.width
                spacing: overview.theme.spacing2

                Text {
                    text: "SPATIAL OVERVIEW · " + overview.windows.length + " WINDOWS"
                    color: overview.theme.accent
                    font.family: overview.runtime.fontMono
                    font.pixelSize: overview.theme.fontPanelEyebrow
                    font.weight: Font.DemiBold
                }
                Text {
                    text: overview.moveMode ? "Move window" : "Your workspaces"
                    color: overview.theme.textStrong
                    font.family: overview.runtime.fontMono
                    font.pixelSize: overview.theme.fontPanelTitle
                    font.weight: Font.DemiBold
                }
            }

            Row {
                width: parent.width
                Text {
                    text: overview.statusText.length > 0 ? overview.statusText : "Windows · Workspace " + overview.focusedWorkspace
                    color: overview.theme.textStrong
                    font.family: overview.runtime.fontMono
                    font.pixelSize: overview.theme.fontSize(12)
                    font.weight: Font.DemiBold
                }
                Item {
                    width: Math.max(0, parent.width - parent.children[0].width - shortcutHint.width)
                    height: 1
                }
                Text {
                    id: shortcutHint
                    text: overview.moveMode ? "H/L DESTINATION   1–0 CHOOSE   ENTER MOVE   ESC CANCEL" : "H/J/K/L NAVIGATE   M MOVE   F FLOAT   P PIN   ENTER FOCUS"
                    color: overview.theme.textMuted
                    font.family: overview.runtime.fontMono
                    font.pixelSize: overview.theme.fontSize(10)
                }
            }

            Row {
                id: workspaceRow
                width: parent.width
                spacing: overview.theme.spacing2

                Repeater {
                    model: 10
                    delegate: ShellAction {
                        required property int index
                        width: (workspaceRow.width - workspaceRow.spacing * 9) / 10
                        height: 45
                        runtime: overview.runtime
                        theme: overview.theme
                        motion: overview.motion
                        compact: true
                        title: index === 9 ? "0" : String(index + 1)
                        active: overview.moveMode ? overview.destinationWorkspace === index + 1 : overview.focusedWorkspace === index + 1
                        enabled: !overview.movePending
                        onActivated: {
                            if (overview.moveMode)
                                overview.executeMove(index + 1);
                            else
                                overview.focusWorkspace(index + 1);
                        }
                    }
                }
            }

            Text {
                text: overview.movePending ? "PENDING · WAITING FOR COMPOSITOR" : overview.moveMode ? "MOVE TARGET · " + (overview.moveTarget ? overview.moveTarget.title : "WINDOW") : overview.windows.length + (overview.windows.length === 1 ? " WINDOW" : " WINDOWS") + "   ·   Workspace " + overview.focusedWorkspace
                color: overview.theme.accent
                font.family: overview.runtime.fontMono
                font.pixelSize: overview.theme.fontSubpanelEyebrow
                font.letterSpacing: 1
            }

            GridView {
                id: windowsGrid
                width: parent.width
                height: Math.max(90, parent.height - 215)
                clip: true
                model: overview.windows
                cellWidth: Math.floor(width / (width < 720 ? 2 : 3))
                cellHeight: 204
                currentIndex: overview.selectedIndex
                boundsBehavior: Flickable.StopAtBounds
                displaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: overview.motion.spatialFast
                        easing.type: overview.motion.spatialType
                        easing.bezierCurve: overview.motion.spatialCurve
                    }
                }
                delegate: OverviewWindow {
                    id: windowTile
                    required property var modelData
                    required property int index
                    width: windowsGrid.cellWidth - overview.theme.spacing2
                    height: windowsGrid.cellHeight - overview.theme.spacing2
                    runtime: overview.runtime
                    theme: overview.theme
                    motion: overview.motion
                    toplevel: modelData
                    active: overview.open
                    selected: overview.moveMode ? overview.moveTarget === modelData : overview.selectedIndex === index
                    onActivated: {
                        if (overview.moveMode) {
                            overview.chooseIndex(index);
                            overview.startMove(index);
                        } else
                            overview.activateWindow(index);
                    }
                    onDragMoved: (x, y) => {
                        if (!overview.moveMode)
                            overview.startMove(index);
                        const destination = overview.hoverDestination(windowTile, x, y);
                        if (destination !== 0)
                            overview.destinationWorkspace = destination;
                    }
                    onDropped: (x, y) => {
                        const destination = overview.hoverDestination(windowTile, x, y);
                        if (destination !== 0)
                            overview.executeMove(destination);
                    }
                }
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

                Text {
                    anchors.centerIn: parent
                    visible: overview.windows.length === 0
                    text: "No open application windows"
                    color: overview.theme.textMuted
                    font.family: overview.runtime.fontMono
                    font.pixelSize: overview.theme.fontSize(13)
                }
            }
            Row {
                width: parent.width
                spacing: overview.theme.spacing3
                height: 39

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(1, parent.width - 304)
                    text: overview.chosenWindow ? (overview.chosenWindow.lastIpcObject.class || "WINDOW") + " · " + (overview.chosenFloating ? "FLOATING" : "TILED") + (overview.chosenPinned ? " · PINNED" : "") : "NO WINDOW SELECTED"
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: overview.theme.textMuted
                    font.family: overview.runtime.fontMono
                    font.pixelSize: overview.theme.fontSize(10)
                }

                ShellAction {
                    width: 137
                    height: 36
                    runtime: overview.runtime
                    theme: overview.theme
                    motion: overview.motion
                    compact: true
                    horizontalCompact: true
                    title: overview.chosenFloating ? "TILE" : "FLOAT"
                    icon: "󰉋"
                    shortcut: "F"
                    active: overview.chosenFloating
                    enabled: !!overview.chosenWindow && !overview.moveMode && !overview.movePending && !overview.actionPending
                    onActivated: overview.toggleWindowState("float")
                }
                ShellAction {
                    width: 137
                    height: 36
                    runtime: overview.runtime
                    theme: overview.theme
                    motion: overview.motion
                    compact: true
                    horizontalCompact: true
                    title: overview.chosenPinned ? "UNPIN" : "PIN"
                    icon: "󰐃"
                    shortcut: "P"
                    active: overview.chosenPinned
                    enabled: !!overview.chosenWindow && overview.chosenFloating && !overview.moveMode && !overview.movePending && !overview.actionPending
                    onActivated: overview.toggleWindowState("pin")
                }
            }
        }
    }

    FocusScope {
        id: keyboard
        anchors.fill: parent
        focus: overview.open
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (overview.moveMode)
                    overview.cancelMove();
                else
                    overview.hide();
            } else if (event.key === Qt.Key_M && !overview.movePending) {
                overview.startMove(overview.selectedIndex);
            } else if (event.key === Qt.Key_F && !overview.moveMode) {
                overview.toggleWindowState("float");
            } else if (event.key === Qt.Key_P && !overview.moveMode) {
                overview.toggleWindowState("pin");
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (overview.moveMode)
                    overview.executeMove(overview.destinationWorkspace);
                else
                    overview.activateWindow(overview.selectedIndex);
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                if (overview.moveMode)
                    overview.destinationWorkspace = event.key - Qt.Key_0;
                else
                    overview.focusWorkspace(event.key - Qt.Key_0);
            } else if (event.key === Qt.Key_0) {
                if (overview.moveMode)
                    overview.destinationWorkspace = 10;
                else
                    overview.focusWorkspace(10);
            } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                if (overview.moveMode)
                    overview.destinationWorkspace = Math.max(1, overview.destinationWorkspace - 1);
                else
                    overview.chooseIndex(Math.max(0, overview.selectedIndex - 1));
            } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                if (overview.moveMode)
                    overview.destinationWorkspace = Math.min(10, overview.destinationWorkspace + 1);
                else
                    overview.chooseIndex(Math.max(0, Math.min(overview.windows.length - 1, overview.selectedIndex + 1)));
            } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                if (overview.moveMode)
                    overview.destinationWorkspace = Math.min(10, overview.destinationWorkspace + 3);
                else
                    overview.chooseIndex(Math.max(0, Math.min(overview.windows.length - 1, overview.selectedIndex + 3)));
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                if (overview.moveMode)
                    overview.destinationWorkspace = Math.max(1, overview.destinationWorkspace - 3);
                else
                    overview.chooseIndex(Math.max(0, overview.selectedIndex - 3));
            } else {
                return;
            }
            event.accepted = true;
        }
    }
}
