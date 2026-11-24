pragma ComponentBehavior: Bound
import QtQuick
import "DesktopIcons.js" as DesktopIcons
import "ContextActions.js" as ContextActions
import Quickshell
import Quickshell.Io

Item {
    id: panel
    // Pre-constructed content hosted by the single permanent modal layer.
    property var screen: null

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool open: false
    property bool closing: false
    property var entries: []
    property int selectedIndex: 0
    property string kindFilter: "all"
    property bool actionMode: false
    property bool actionReturnToList: false
    property int actionIndex: 0
    property var actionTarget: null
    property string priorQuery: ""
    property bool deleteArmed: false
    property bool hideAfterCopy: false

    ContextActionModel {
        id: contextActions
        actions: ContextActions.clipboardActions(panel.actionTarget, !!panel.safeSelectedLink)
        query: panel.actionMode ? search.text : ""
    }

    readonly property string safeSelectedLink: panel.actionTarget && panel.actionTarget.id === panel.previewTextEntryId ? ContextActions.safeWebUrl(panel.previewText) : ""

    property string copyFeedback: ""
    property string previewText: ""
    property var previewTextEntryId: -1
    // cliphist list already supplies selected text: render that in the same
    // frame as navigation, then replace it with the full decoded entry.
    readonly property string selectedText: currentEntry && currentEntry.kind === "TEXT" ? (previewTextEntryId === currentEntry.id ? previewText : currentEntry.preview) : ""
    property string previewImagePath: ""
    property var previewJobId: -1
    property string previewJobKind: ""
    readonly property var currentEntry: filteredEntries.length > 0 ? filteredEntries[Math.max(0, Math.min(selectedIndex, filteredEntries.length - 1))] : null
    signal copyCompleted(bool success)

    readonly property var filteredEntries: ContextActions.historyFilter(entries, actionMode ? priorQuery : search.text, kindFilter)
    readonly property var visibleEntries: actionMode ? contextActions.matches : filteredEntries

    visible: open || closing

    anchors.fill: parent

    property StdioCollector queryOutput: StdioCollector {}
    property StdioCollector queryError: StdioCollector {}
    property StdioCollector copyError: StdioCollector {}
    property StdioCollector operationError: StdioCollector {}
    property Process operationProcess: Process {
        stderr: panel.operationError
        onExited: (exitCode, exitStatus) => {
            panel.copyFeedback = exitCode === 0 ? "UPDATED" : "OPERATION FAILED";
            panel.deleteArmed = false;
            if (exitCode === 0)
                panel.refresh();
        }
    }

    property Process queryProcess: Process {
        stdout: panel.queryOutput
        stderr: panel.queryError

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                panel.entries = panel.parseHistory(panel.queryOutput.text);
            else
                panel.entries = [];

            panel.selectedIndex = 0;
        }
    }

    property StdioCollector previewOutput: StdioCollector {}
    property Process previewProcess: Process {
        stdout: panel.previewOutput
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && panel.currentEntry && panel.open && panel.currentEntry.id === panel.previewJobId && (panel.previewJobKind === "text" || panel.currentEntry.kind === "IMAGE")) {
                if (panel.previewJobKind === "text") {
                    panel.previewText = panel.previewOutput.text.slice(0, 8192);
                    panel.previewTextEntryId = panel.previewJobId;
                } else
                    panel.previewImagePath = panel.previewOutput.text.trim();
            }
            if (panel.currentEntry && panel.open && (panel.currentEntry.id !== panel.previewJobId || (panel.currentEntry.kind === "IMAGE" && panel.previewJobKind !== "image")))
                previewTimer.restart();
            if (!panel.open && !panel.closing)
                panel.clearPreviewFiles();
        }
    }

    Timer {
        id: previewTimer
        // Coalesce rapid navigation within one event loop, not 100 ms.
        interval: 0
        onTriggered: panel.loadPreview()
    }

    onCurrentEntryChanged: {
        previewTextEntryId = -1;
        previewText = "";
        previewImagePath = "";
        if (open)
            previewTimer.restart();
    }

    function loadPreview(): void {
        if (!open || !currentEntry || runtime.clipboardPreview.length === 0 || previewProcess.running)
            return;
        if (currentEntry.kind !== "TEXT" && currentEntry.kind !== "IMAGE")
            return;
        previewJobId = currentEntry.id;
        previewJobKind = currentEntry.kind === "TEXT" ? "text" : "image";
        if (previewJobKind === "text")
            previewProcess.exec(currentEntry.pinned ? [runtime.clipboardOperations, "read", String(previewJobId)] : [runtime.cliphist, "decode", String(previewJobId)]);
        else
            previewProcess.exec([runtime.clipboardPreview, "image", String(previewJobId)]);
    }

    function clearPreviewFiles(): void {
        previewImagePath = "";
        previewTextEntryId = -1;
        previewText = "";
        if (runtime.clipboardPreview.length > 0)
            Quickshell.execDetached([runtime.clipboardPreview, "clear"]);
    }

    property Process copyProcess: Process {
        stderr: panel.copyError
        onExited: (exitCode, exitStatus) => {
            const success = exitCode === 0;
            panel.copyFeedback = success ? "COPIED" : "COPY FAILED";
            panel.copyCompleted(success);
            if (success && panel.hideAfterCopy)
                panel.hide();
            panel.hideAfterCopy = false;
        }
    }

    Timer {
        id: closeTimer
        interval: panel.motion.normal + (panel.motion.enabled ? 24 : 0)
        onTriggered: {
            panel.closing = false;
            if (!panel.open && !panel.previewProcess.running)
                panel.clearPreviewFiles();
        }
    }

    onFilteredEntriesChanged: {
        selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, filteredEntries.length - 1)));
    }

    function sanitisePreview(raw: string): var {
        const compact = raw.replace(/\r/g, " ").replace(/\n/g, " ").replace(/\s+/g, " ").trim();

        if (compact.length === 0)
            return {
                kind: "TEXT",
                preview: "[empty clipboard item]"
            };

        let suspicious = 0;
        const sample = compact.slice(0, 160);

        for (let i = 0; i < sample.length; i++) {
            const code = sample.charCodeAt(i);
            if (code === 0xfffd || code < 32 || (code >= 127 && code <= 159))
                suspicious++;
        }

        if (/^\[\[ binary data .* (png|jpeg|jpg|webp|gif|bmp) \d+x\d+ \]\]$/i.test(compact))
            return {
                kind: "IMAGE",
                preview: compact.slice(3, -3)
            };

        if (suspicious >= 3 || suspicious / sample.length > 0.08 || compact.startsWith("[[ binary data"))
            return {
                kind: "BINARY",
                preview: "[binary clipboard item]"
            };

        return {
            kind: "TEXT",
            preview: compact
        };
    }

    function parseHistory(output: string): var {
        const parsed = [];

        for (const line of output.split("\n")) {
            const tab = line.indexOf("\t");
            if (tab <= 0)
                continue;

            const identity = line.slice(0, tab);
            if (/^pin:[a-f0-9]{64}$/.test(identity)) {
                const next = line.indexOf("\t", tab + 1);
                if (next < 0)
                    continue;
                const kind = line.slice(tab + 1, next);
                if (!["TEXT", "IMAGE", "BINARY"].includes(kind))
                    continue;
                parsed.push({
                    id: identity,
                    kind: kind,
                    pinned: true,
                    preview: line.slice(next + 1)
                });
                continue;
            }
            if (!/^[0-9]+$/.test(identity))
                continue;
            const safe = sanitisePreview(line.slice(tab + 1));
            parsed.push({
                id: parseInt(identity),
                kind: safe.kind,
                pinned: false,
                preview: safe.preview
            });
        }

        return parsed;
    }

    function refresh(): void {
        if (queryProcess.running)
            return;
        if (runtime.clipboardOperations.length > 0)
            queryProcess.exec([runtime.clipboardOperations, "list"]);
        else if (runtime.cliphist.length > 0)
            queryProcess.exec([runtime.cliphist, "list"]);
    }

    function show(): void {
        closeTimer.stop();
        open = true;
        closing = false;
        search.text = "";
        copyFeedback = "";
        selectedIndex = 0;
        actionMode = false;
        actionTarget = null;
        kindFilter = "all";
        deleteArmed = false;
        refresh();
        previewTimer.restart();
        search.forceActiveFocus();
    }

    function hide(): void {
        if (!open)
            return;
        actionMode = false;
        actionTarget = null;
        deleteArmed = false;

        // Preserve the Wayland surface until the longer spatial exit finishes.
        closing = motion.enabled;
        open = false;

        if (closing)
            closeTimer.restart();
        else if (!previewProcess.running)
            clearPreviewFiles();
    }

    function toggle(): void {
        if (open)
            hide();
        else
            show();
    }

    function copyEntry(entry: var, closeOnSuccess: bool): bool {
        if (!entry || copyProcess.running)
            return false;
        const tool = entry.pinned ? runtime.clipboardOperations : runtime.clipboardCopy;
        if (!tool)
            return false;
        hideAfterCopy = closeOnSuccess;
        copyFeedback = "COPYING";
        copyProcess.exec(entry.pinned ? [tool, "copy", entry.id] : [tool, String(entry.id)]);
        return true;
    }

    function openActions(): void {
        if (actionMode || !currentEntry)
            return;
        priorQuery = search.text;
        actionReturnToList = list.activeFocus;
        actionTarget = currentEntry;
        actionIndex = 0;
        deleteArmed = false;
        actionMode = true;
        search.text = "";
        search.forceActiveFocus();
    }

    function leaveActions(): void {
        const target = actionTarget;
        actionMode = false;
        actionTarget = null;
        deleteArmed = false;
        search.text = priorQuery;
        if (target)
            selectedIndex = Math.max(0, filteredEntries.findIndex(item => item.id === target.id));
        search.forceActiveFocus();
    }

    function toggleActions(): void {
        if (actionMode) {
            leaveActions();
            if (actionReturnToList && filteredEntries.length > 0)
                list.forceActiveFocus();
        } else
            openActions();
    }

    function executeAction(): void {
        if (!actionMode || actionIndex < 0 || actionIndex >= contextActions.matches.length)
            return;
        const action = contextActions.matches[actionIndex].action;
        const entry = actionTarget;
        if (!entry)
            return;
        if (action === "delete" && !deleteArmed) {
            deleteArmed = true;
            copyFeedback = "SELECT DELETE AGAIN TO CONFIRM";
            return;
        }
        leaveActions();
        if (action === "copy") {
            copyEntry(entry, true);
            return;
        }
        if (action === "openLink") {
            const url = ContextActions.safeWebUrl(previewText);
            if (url && entry.id === previewTextEntryId) {
                hide();
                Quickshell.execDetached([runtime.urlOpen, url]);
            }
            return;
        }
        if (operationProcess.running || !runtime.clipboardOperations) {
            copyFeedback = "OPERATION IN PROGRESS";
            return;
        }
        copyFeedback = "APPLYING";
        operationProcess.exec(action === "pin" ? [runtime.clipboardOperations, "pin", String(entry.id), entry.kind] : [runtime.clipboardOperations, action, String(entry.id)]);
    }

    function activateSelected(): void {
        if (actionMode) {
            executeAction();
            return;
        }
        if (currentEntry)
            copyEntry(currentEntry, true);
    }

    Rectangle {
        anchors.fill: parent
        color: panel.theme.scrim
        opacity: 0 // Background dimming is compositor-owned in this benchmark.

        Behavior on opacity {
            NumberAnimation {
                duration: panel.motion.fast
                easing.type: panel.open ? panel.motion.enterType : panel.motion.exitType
                easing.bezierCurve: panel.open ? panel.motion.enterCurve : panel.motion.exitCurve
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: panel.hide()
        }
    }

    ShellSurface {
        id: card

        width: Math.min(panel.width - 72, 1020)
        height: Math.min(panel.height - 120, 680)
        anchors.centerIn: parent

        theme: panel.theme
        motion: panel.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusPanel

        scale: panel.open ? 1 : theme.panelClosedScale
        opacity: panel.open ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: panel.motion.normal
                easing.type: panel.open ? panel.motion.enterType : panel.motion.exitType
                easing.bezierCurve: panel.open ? panel.motion.enterCurve : panel.motion.exitCurve
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: panel.motion.fast
                easing.type: panel.motion.effectsType
                easing.bezierCurve: panel.motion.effectsCurve
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: panel.theme.spacing5

            Column {
                id: qmlHeader
                width: parent.width
                spacing: panel.theme.spacing2

                DetailHero {
                    width: parent.width
                    runtime: panel.runtime
                    theme: panel.theme
                    motion: panel.motion
                    glyph: DesktopIcons.glyphFor("clipboard")
                    glyphFont: "Symbols Nerd Font"
                    glyphColor: panel.theme.roleColor("clipboard")
                    eyebrow: "History / Clipboard"
                    title: "Clipboard"
                    detail: panel.actionMode ? "Actions for selected item" : panel.entries.length + (panel.entries.length === 1 ? " item" : " items")
                }

                SearchFieldSurface {
                    width: parent.width
                    height: 50
                    theme: panel.theme
                    motion: panel.motion
                    fieldFocused: search.activeFocus

                    TextInput {
                        id: search

                        anchors {
                            fill: parent
                            leftMargin: panel.theme.spacing4
                            rightMargin: panel.theme.spacing4
                        }

                        verticalAlignment: TextInput.AlignVCenter
                        color: panel.theme.textStrong
                        selectionColor: panel.theme.accent
                        selectedTextColor: panel.theme.background
                        font.family: panel.runtime.fontSans
                        font.pixelSize: panel.theme.fontSize(14)
                        clip: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: panel.actionMode ? "Search actions…" : "Search clipboard…"
                            visible: search.text.length === 0
                            color: panel.theme.textMuted
                            font: search.font
                        }

                        onTextChanged: {
                            if (panel.actionMode)
                                panel.actionIndex = 0;
                            panel.deleteArmed = false;
                        }

                        Keys.onPressed: event => {
                            if (event.isAutoRepeat && (event.key === panel.runtime.shellKeyCode("clipboard", "Return") || event.key === panel.runtime.shellKeyCode("clipboard", "Enter"))) {
                                event.accepted = true;
                                return;
                            }
                            if ((event.key === panel.runtime.shellKeyCode("clipboard", "Return") || event.key === panel.runtime.shellKeyCode("clipboard", "Enter")) && panel.runtime.shellModifier("clipboard", "Alt", event.modifiers)) {
                                panel.toggleActions();
                                event.accepted = true;
                            } else if (event.key === panel.runtime.shellKeyCode("clipboard", "Tab")) {
                                list.forceActiveFocus();
                                event.accepted = true;
                            } else if (event.key === panel.runtime.shellKeyCode("clipboard", "Escape")) {
                                if (panel.actionMode)
                                    panel.toggleActions();
                                else
                                    panel.hide();
                                event.accepted = true;
                            } else if (panel.runtime.shellNavigates("clipboard", "down", event.key, "arrows")) {
                                if (panel.actionMode)
                                    panel.actionIndex = Math.min(panel.visibleEntries.length - 1, panel.actionIndex + 1);
                                else
                                    panel.selectedIndex = Math.min(panel.filteredEntries.length - 1, panel.selectedIndex + 1);
                                event.accepted = true;
                            } else if (panel.runtime.shellNavigates("clipboard", "up", event.key, "arrows")) {
                                if (panel.actionMode)
                                    panel.actionIndex = Math.max(0, panel.actionIndex - 1);
                                else
                                    panel.selectedIndex = Math.max(0, panel.selectedIndex - 1);
                                event.accepted = true;
                            } else if (event.key === panel.runtime.shellKeyCode("clipboard", "Return") || event.key === panel.runtime.shellKeyCode("clipboard", "Enter")) {
                                panel.activateSelected();
                                event.accepted = true;
                            }
                        }
                    }
                }

                Row {
                    visible: !panel.actionMode
                    height: visible ? 32 : 0
                    spacing: panel.theme.spacing2
                    Repeater {
                        model: [
                            {
                                id: "all",
                                name: "All"
                            },
                            {
                                id: "TEXT",
                                name: "Text"
                            },
                            {
                                id: "IMAGE",
                                name: "Images"
                            },
                            {
                                id: "pinned",
                                name: "Pinned"
                            }
                        ]
                        delegate: ShellAction {
                            required property var modelData
                            width: 85
                            height: 32
                            runtime: panel.runtime
                            theme: panel.theme
                            motion: panel.motion
                            compact: true
                            title: modelData.name
                            active: panel.kindFilter === modelData.id
                            onActivated: {
                                panel.kindFilter = modelData.id;
                                panel.selectedIndex = 0;
                            }
                        }
                    }
                }
            }

            ListView {
                id: list

                anchors {
                    top: qmlHeader.bottom
                    right: previewPane.visible ? previewPane.left : parent.right
                    bottom: qmlFooter.top
                    left: parent.left
                    rightMargin: previewPane.visible ? panel.theme.spacing3 : 0
                    topMargin: panel.theme.spacing4
                    bottomMargin: panel.theme.spacing4
                }

                model: panel.visibleEntries
                spacing: panel.theme.spacing2
                clip: true
                currentIndex: panel.actionMode ? panel.actionIndex : panel.selectedIndex
                boundsBehavior: Flickable.StopAtBounds

                Keys.priority: Keys.BeforeItem
                Keys.onPressed: event => {
                    if (event.isAutoRepeat && (event.key === panel.runtime.shellKeyCode("clipboard", "Return") || event.key === panel.runtime.shellKeyCode("clipboard", "Enter"))) {
                        event.accepted = true;
                        return;
                    }
                    if ((event.key === panel.runtime.shellKeyCode("clipboard", "Return") || event.key === panel.runtime.shellKeyCode("clipboard", "Enter")) && panel.runtime.shellModifier("clipboard", "Alt", event.modifiers)) {
                        panel.toggleActions();
                    } else if (event.key === panel.runtime.shellKeyCode("clipboard", "Tab") || event.key === panel.runtime.shellKeyCode("clipboard", "I") || event.key === panel.runtime.shellKeyCode("clipboard", "Slash")) {
                        search.forceActiveFocus();
                    } else if (event.key === panel.runtime.shellKeyCode("clipboard", "Escape")) {
                        if (panel.actionMode)
                            panel.toggleActions();
                        else
                            panel.hide();
                    } else if (panel.runtime.shellNavigates("clipboard", "down", event.key)) {
                        if (panel.actionMode)
                            panel.actionIndex = Math.min(panel.visibleEntries.length - 1, panel.actionIndex + 1);
                        else
                            panel.selectedIndex = Math.min(panel.filteredEntries.length - 1, panel.selectedIndex + 1);
                    } else if (panel.runtime.shellNavigates("clipboard", "up", event.key)) {
                        if (panel.actionMode)
                            panel.actionIndex = Math.max(0, panel.actionIndex - 1);
                        else
                            panel.selectedIndex = Math.max(0, panel.selectedIndex - 1);
                    } else if (event.key === panel.runtime.shellKeyCode("clipboard", "U") || event.key === panel.runtime.shellKeyCode("clipboard", "PageUp") || event.key === panel.runtime.shellKeyCode("clipboard", "D") || event.key === panel.runtime.shellKeyCode("clipboard", "PageDown")) {
                        const rowHeight = list.currentItem ? list.currentItem.height + list.spacing : 62;
                        const rows = Math.max(1, Math.floor(list.height / Math.max(1, rowHeight) / 2));
                        const delta = ((event.key === panel.runtime.shellKeyCode("clipboard", "D") || event.key === panel.runtime.shellKeyCode("clipboard", "PageDown")) ? rows : -rows);
                        if (panel.actionMode)
                            panel.actionIndex = Math.max(0, Math.min(panel.visibleEntries.length - 1, panel.actionIndex + delta));
                        else
                            panel.selectedIndex = Math.max(0, Math.min(panel.filteredEntries.length - 1, panel.selectedIndex + delta));
                    } else if (event.key === panel.runtime.shellKeyCode("clipboard", "Return") || event.key === panel.runtime.shellKeyCode("clipboard", "Enter")) {
                        panel.activateSelected();
                    } else {
                        return;
                    }
                    event.accepted = true;
                }

                delegate: SquircleSurface {
                    id: item

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: Math.max(62, moreAction.implicitHeight + panel.theme.spacing2)
                    exponent: panel.theme.squircleExponent
                    cornerRadius: panel.theme.radiusMedium
                    fillColor: index === list.currentIndex ? panel.theme.focusFill : panel.theme.background
                    borderColor: index === list.currentIndex ? panel.theme.roleColor("clipboard") : panel.theme.outline
                    borderWidth: index === list.currentIndex ? panel.theme.borderFocus : panel.theme.borderThin

                    StateLayer {
                        theme: panel.theme
                        motion: panel.motion
                        selected: item.index === list.currentIndex
                        cornerRadius: panel.theme.radiusMedium
                        onActivated: {
                            if (panel.actionMode)
                                panel.actionIndex = item.index;
                            else
                                panel.selectedIndex = item.index;
                        }
                        onDoubleClicked: {
                            if (panel.actionMode)
                                panel.actionIndex = item.index;
                            else
                                panel.selectedIndex = item.index;
                            panel.activateSelected();
                        }
                    }

                    Row {
                        anchors {
                            fill: parent
                            margins: panel.theme.spacing3
                        }
                        spacing: panel.theme.spacing3

                        Text {
                            width: 64
                            anchors.verticalCenter: parent.verticalCenter
                            text: item.modelData ? (panel.actionMode ? "ACTION" : item.modelData.pinned ? "PINNED" : item.modelData.kind || "") : ""
                            color: panel.theme.readableRoleColor(item.modelData && item.modelData.kind === "TEXT" ? "clipboard" : "capture")
                            font.family: panel.runtime.fontSans
                            font.pixelSize: panel.theme.fontSize(9)
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.8
                        }

                        MarqueeText {
                            width: Math.max(1, parent.width - 64 - parent.spacing - moreAction.implicitWidth)
                            anchors.verticalCenter: parent.verticalCenter
                            text: item.modelData ? (panel.actionMode ? item.modelData.name || "" : item.modelData.preview || "") : ""
                            color: panel.theme.text
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(12)
                        }
                    }

                    ShellAction {
                        id: moreAction
                        anchors.right: parent.right
                        anchors.rightMargin: panel.theme.spacing2
                        anchors.verticalCenter: parent.verticalCenter
                        width: implicitWidth
                        height: implicitHeight
                        visible: !panel.actionMode && item.index === panel.selectedIndex
                        runtime: panel.runtime
                        theme: panel.theme
                        motion: panel.motion
                        compact: true
                        iconOnly: true
                        icon: "󰍉"
                        title: "More actions"
                        inlineIconHint: true
                        shortcut: panel.runtime.shellHint("ClipboardPanel.actionMenu")
                        onActivated: {
                            panel.selectedIndex = item.index;
                            panel.openActions();
                        }
                    }
                }

                onCurrentIndexChanged: {
                    positionViewAtIndex(currentIndex, ListView.Contain);
                    panel.deleteArmed = false;
                }
            }

            ShellSurface {
                id: previewPane
                visible: card.width >= 820
                anchors {
                    top: list.top
                    right: parent.right
                    bottom: list.bottom
                }
                width: 340
                theme: panel.theme
                motion: panel.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: panel.theme.radiusMedium
                clip: true

                Column {
                    anchors {
                        fill: parent
                        margins: panel.theme.spacing4
                    }
                    spacing: panel.theme.spacing3

                    Row {
                        width: parent.width
                        spacing: panel.theme.spacing2
                        Text {
                            text: "◈"
                            color: panel.theme.roleColor("clipboard")
                            font.family: panel.runtime.fontSans
                            font.pixelSize: panel.theme.fontSize(19)
                        }
                        Column {
                            spacing: panel.theme.spacing1
                            ShellText {
                                text: "SELECTED ITEM"
                                runtime: panel.runtime
                                theme: panel.theme
                                color: panel.theme.textMuted
                                font.pixelSize: panel.theme.fontSize(10)
                            }
                            ShellText {
                                text: panel.currentEntry ? panel.currentEntry.kind + " · #" + panel.currentEntry.id : "EMPTY"
                                runtime: panel.runtime
                                theme: panel.theme
                                color: panel.theme.textStrong
                                font.pixelSize: panel.theme.fontSize(12)
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    ShellSurface {
                        width: parent.width
                        height: Math.max(90, previewPane.height - 178)
                        theme: panel.theme
                        motion: panel.motion
                        surfaceLayer: ShellSurface.Control
                        cornerRadius: panel.theme.radiusMedium
                        clip: true

                        Flickable {
                            id: textPreview
                            anchors {
                                fill: parent
                                margins: panel.theme.spacing3
                            }
                            visible: !!panel.currentEntry && panel.currentEntry.kind === "TEXT"
                            contentHeight: previewBody.implicitHeight
                            contentWidth: width
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Text {
                                id: previewBody
                                width: textPreview.width
                                text: panel.selectedText
                                wrapMode: Text.WrapAnywhere
                                color: panel.theme.textStrong
                                font.family: panel.runtime.fontMono
                                font.pixelSize: panel.theme.fontSize(12)
                                lineHeight: 1.4
                                textFormat: Text.PlainText
                            }
                        }

                        Image {
                            anchors {
                                fill: parent
                                margins: panel.theme.spacing2
                            }
                            visible: !!panel.currentEntry && panel.currentEntry.kind === "IMAGE" && panel.previewImagePath.length > 0
                            source: panel.previewImagePath.length > 0 ? "file://" + panel.previewImagePath : ""
                            asynchronous: true
                            cache: false
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Column {
                            visible: !!panel.currentEntry && panel.currentEntry.kind !== "TEXT" && panel.previewImagePath.length === 0
                            anchors.centerIn: parent
                            width: parent.width - panel.theme.spacing5 * 2
                            spacing: panel.theme.spacing4
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "▧"
                                color: panel.theme.roleColor("clipboard")
                                font.family: panel.runtime.fontSans
                                font.pixelSize: panel.theme.fontSize(44)
                            }
                            ShellText {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                runtime: panel.runtime
                                theme: panel.theme
                                text: panel.currentEntry && panel.currentEntry.kind === "IMAGE" ? "Rendering thumbnail…" : "Binary item · Preview unavailable"
                                color: panel.theme.textMuted
                                font.pixelSize: panel.theme.fontSize(11)
                            }
                        }
                    }

                    ShellText {
                        width: parent.width
                        runtime: panel.runtime
                        theme: panel.theme
                        text: panel.copyFeedback
                        color: panel.copyFeedback === "COPY FAILED" ? panel.theme.readableRoleColor("critical") : panel.theme.textMuted
                        font.pixelSize: panel.theme.fontSize(10)
                        elide: Text.ElideRight
                    }
                }
            }

            Text {
                anchors.centerIn: list
                visible: !panel.queryProcess.running && panel.visibleEntries.length === 0
                text: search.text.length > 0 ? "NO MATCHES" : "CLIPBOARD HISTORY IS EMPTY"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontSans
                font.pixelSize: panel.theme.fontSize(11)
                font.letterSpacing: 1.1
            }

            Text {
                anchors.centerIn: list
                visible: panel.queryProcess.running
                text: "Loading history…"
                color: panel.theme.readableRoleColor("clipboard")
                font.family: panel.runtime.fontSans
                font.pixelSize: panel.theme.fontSize(11)
                font.letterSpacing: 1.1
            }

            KeyHintStrip {
                id: qmlFooter
                width: parent.width
                anchors.bottom: parent.bottom
                runtime: panel.runtime
                theme: panel.theme
                hints: [
                    {
                        shortcut: search.activeFocus ? panel.runtime.shellHint("ClipboardPanel.navigateSearch") : panel.runtime.shellHint("ClipboardPanel.navigateList"),
                        label: "Select"
                    },
                    {
                        shortcut: panel.runtime.shellHint("ClipboardPanel.focusSearch"),
                        label: search.activeFocus ? "Results" : "Search"
                    },
                    {
                        shortcut: panel.runtime.shellHint("ClipboardPanel.halfPage"),
                        label: "Half page",
                        visible: !search.activeFocus
                    },
                    {
                        shortcut: panel.runtime.shellHint("ClipboardPanel.copy"),
                        label: panel.actionMode ? "Run" : "Copy"
                    },
                    {
                        shortcut: panel.runtime.shellHint("ClipboardPanel.actionMenu"),
                        label: panel.actionMode ? "Clipboard" : "Actions",
                        visible: panel.actionMode || panel.selectedIndex < 0 || panel.filteredEntries.length === 0
                    },
                    {
                        shortcut: panel.runtime.shellHint("ClipboardPanel.close"),
                        label: panel.actionMode ? "Back" : "Close"
                    }
                ]
            }
        }
    }
}
