pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

Item {
    id: overview
    // Pre-constructed content hosted by the single permanent modal layer.
    property var screen: null

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool open: false
    property bool closing: false
    // Workspace activation can cause the compositor to hand the keyboard to
    // a toplevel, even while our overview layer is still visible. Reassert
    // layer-shell keyboard interactivity without closing the overview.
    property bool keyboardFocusRefreshing: false
    property int selectedIndex: 0
    property string selectedAddress: ""
    property bool moveMode: false
    property bool showAllWorkspaces: true
    property int browsedWorkspace: 1
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

    readonly property var allWindows: Hyprland.toplevels.values.filter(toplevel => {
        if (!toplevel || !toplevel.workspace || toplevel.workspace.id <= 0)
            return false;
        // Some compositor helper surfaces are exposed as toplevels without an app identity.
        const info = toplevel.lastIpcObject || {};
        return Boolean(info.class || (toplevel.wayland && toplevel.wayland.appId));
    }).sort((left, right) => left.workspace.id - right.workspace.id || left.title.localeCompare(right.title))
    readonly property var windows: showAllWorkspaces ? allWindows : allWindows.filter(toplevel => toplevel.workspace && toplevel.workspace.id === browsedWorkspace)
    readonly property int focusedWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property string scopeLabel: showAllWorkspaces ? "All workspaces" : "Workspace " + browsedWorkspace

    visible: open || closing
    anchors.fill: parent

    onFocusedWorkspaceChanged: {
        if (!open)
            return;
        keyboardFocusRefreshing = true;
        Qt.callLater(() => {
            keyboardFocusRefreshing = false;
            if (open)
                keyboard.forceActiveFocus();
        });
    }

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
        const tabsStart = allWorkspacesAction.width + workspaceRow.spacing;
        if (point.x < tabsStart || point.x > workspaceRow.width || point.y < 0 || point.y > workspaceRow.height)
            return 0;
        const section = (workspaceRow.width - tabsStart) / 10;
        const index = Math.max(0, Math.min(9, Math.floor((point.x - tabsStart) / Math.max(1, section))));
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
        showAllWorkspaces = true;
        browsedWorkspace = Math.max(1, Math.min(10, focusedWorkspace));
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
        // Browse without switching the compositor workspace underneath this
        // layer. Only activating a window or an empty workspace changes focus.
        browsedWorkspace = id;
        showAllWorkspaces = false;
        chooseIndex(0);
        keyboard.forceActiveFocus();
    }
    function browseAllWorkspaces(): void {
        if (moveMode)
            return;
        showAllWorkspaces = true;
        chooseIndex(Math.max(0, windows.findIndex(toplevel => toplevel.activated)));
        keyboard.forceActiveFocus();
    }
    function activateSelection(): void {
        if (chosenWindow) {
            activateWindow(selectedIndex);
        } else if (!showAllWorkspaces) {
            hide();
            Hyprland.dispatch('hl.dsp.focus({ workspace = "' + browsedWorkspace + '" })');
        }
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
        opacity: 0 // Background dimming is compositor-owned in this benchmark.
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
        width: Math.min(overview.width - 64, 1460)
        height: Math.min(overview.height - 64, overview.windows.length === 0 ? 500 : 330 + Math.min(3, Math.ceil(overview.windows.length / (overview.windows.length <= 4 ? 2 : 3))) * 350)
        theme: overview.theme
        motion: overview.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusPanel
        fillColor: theme.materialContainerLow
        clip: true
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

        ColumnLayout {
            anchors {
                fill: parent
                margins: overview.theme.spacing4
            }
            spacing: overview.theme.spacing3

            RowLayout {
                Layout.fillWidth: true
                spacing: overview.theme.spacing3

                Column {
                    spacing: overview.theme.spacing1
                    Text {
                        text: "SPATIAL OVERVIEW"
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

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: overview.statusText.length > 0 ? overview.statusText : overview.scopeLabel.toUpperCase() + " · " + overview.windows.length + (overview.windows.length === 1 ? " WINDOW" : " WINDOWS")
                    color: overview.theme.textMuted
                    font.family: overview.runtime.fontMono
                    font.pixelSize: overview.theme.fontSize(11)
                }
            }

            Row {
                id: workspaceRow
                Layout.fillWidth: true
                spacing: overview.theme.spacing2

                ShellAction {
                    id: allWorkspacesAction
                    width: 110
                    height: 44
                    runtime: overview.runtime
                    theme: overview.theme
                    motion: overview.motion
                    compact: true
                    title: "ALL"
                    shortcut: "A"
                    active: overview.showAllWorkspaces && !overview.moveMode
                    enabled: !overview.moveMode && !overview.movePending
                    onActivated: overview.browseAllWorkspaces()
                }
                Repeater {
                    model: 10
                    delegate: ShellAction {
                        required property int index
                        width: Math.max(1, (workspaceRow.width - 110 - workspaceRow.spacing * 10) / 10)
                        height: 44
                        runtime: overview.runtime
                        theme: overview.theme
                        motion: overview.motion
                        compact: true
                        title: index === 9 ? "0" : String(index + 1)
                        active: overview.moveMode ? overview.destinationWorkspace === index + 1 : overview.showAllWorkspaces ? overview.focusedWorkspace === index + 1 : overview.browsedWorkspace === index + 1
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

            RowLayout {
                Layout.fillWidth: true
                spacing: overview.theme.spacing3
                Text {
                    Layout.fillWidth: true
                    text: overview.movePending ? "WAITING FOR COMPOSITOR" : overview.moveMode ? "MOVE TARGET · " + (overview.moveTarget ? overview.moveTarget.title : "WINDOW") : overview.showAllWorkspaces ? "ALL DESKTOP WINDOWS" : "WORKSPACE " + overview.browsedWorkspace
                    color: overview.theme.accent
                    font.family: overview.runtime.fontMono
                    font.pixelSize: overview.theme.fontSubpanelEyebrow
                    font.letterSpacing: 0.6
                }
                KeyHintStrip {
                    Layout.preferredWidth: Math.min(650, Math.max(200, card.width * 0.56))
                    runtime: overview.runtime
                    theme: overview.theme
                    hints: overview.moveMode ? [
                        {
                            shortcut: "1–0",
                            label: "Destination"
                        },
                        {
                            shortcut: "H/L",
                            label: "Target"
                        },
                        {
                            shortcut: "ENTER",
                            label: "Move"
                        },
                        {
                            shortcut: "ESC",
                            label: "Cancel"
                        }
                    ] : [
                        {
                            shortcut: "1–0",
                            label: "Workspace"
                        },
                        {
                            shortcut: "H/J/K/L",
                            label: "Navigate"
                        },
                        {
                            shortcut: "M",
                            label: "Move"
                        },
                        {
                            shortcut: "ENTER",
                            label: "Open"
                        },
                        {
                            shortcut: "ESC",
                            label: "Close"
                        }
                    ]
                }
            }

            GridView {
                id: windowsGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 120
                clip: true
                model: overview.windows
                readonly property int columns: width < 850 ? 2 : Math.min(4, Math.max(2, Math.ceil(Math.sqrt(Math.max(1, overview.windows.length)))))
                cellWidth: Math.max(1, Math.floor(width / columns))
                cellHeight: Math.min(360, Math.max(205, Math.floor(cellWidth * 0.65)))
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
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && count > 0)
                        positionViewAtIndex(currentIndex, GridView.Contain);
                }

                Text {
                    anchors.centerIn: parent
                    visible: overview.windows.length === 0
                    text: overview.showAllWorkspaces ? "No open application windows" : "Workspace " + overview.browsedWorkspace + " is empty · ENTER to switch"
                    color: overview.theme.textMuted
                    font.family: overview.runtime.fontMono
                    font.pixelSize: overview.theme.fontSize(13)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 43
                spacing: overview.theme.spacing3
                Text {
                    Layout.fillWidth: true
                    text: overview.chosenWindow ? (overview.chosenWindow.lastIpcObject.class || "WINDOW") + " · WS " + overview.chosenWindow.workspace.id + " · " + (overview.chosenFloating ? "FLOATING" : "TILED") + (overview.chosenPinned ? " · PINNED" : "") : overview.scopeLabel
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: overview.theme.textMuted
                    font.family: overview.runtime.fontMono
                    font.pixelSize: overview.theme.fontSize(11)
                }
                ShellAction {
                    width: 126
                    height: 40
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
                    width: 126
                    height: 40
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
                    overview.activateSelection();
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
            } else if (event.key === Qt.Key_A && !overview.moveMode) {
                overview.browseAllWorkspaces();
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
                    overview.chooseIndex(Math.max(0, Math.min(overview.windows.length - 1, overview.selectedIndex + windowsGrid.columns)));
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                if (overview.moveMode)
                    overview.destinationWorkspace = Math.max(1, overview.destinationWorkspace - 3);
                else
                    overview.chooseIndex(Math.max(0, overview.selectedIndex - windowsGrid.columns));
            } else {
                return;
            }
            event.accepted = true;
        }
    }
}
