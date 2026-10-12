import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import "Calculator.js" as Calculator
import "SymbolLibrary.js" as SymbolLibrary

PanelWindow {
    id: palette

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property ClipboardPanel clipboardPanel

    property var commands: []
    signal commandTriggered(string commandId)

    property bool open: false
    property bool closing: false
    property bool copyOnSuccessClose: false
    property string copyFeedback: ""
    property bool clipboardQueried: false
    property bool awaitingClipboardCopy: false

    Connections {
        target: palette.clipboardPanel
        function onCopyCompleted(success) {
            if (!palette.awaitingClipboardCopy)
                return;
            palette.awaitingClipboardCopy = false;
            palette.copyFeedback = success ? "COPIED" : "COPY FAILED";
            if (success && palette.copyOnSuccessClose)
                palette.hide();
        }
    }

    Process {
        id: calculationCopy
        onExited: (exitCode, exitStatus) => {
            palette.copyFeedback = exitCode === 0 ? "COPIED" : "COPY FAILED";
            if (exitCode === 0 && palette.copyOnSuccessClose)
                palette.hide();
        }
    }

    visible: open || closing
    color: "transparent"
    focusable: open
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    WlrLayershell.namespace: "linux-desktop-launcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Shortcut {
        sequence: "Shift+Esc"
        context: Qt.ApplicationShortcut
        enabled: palette.open
        onActivated: palette.hide()
    }

    Timer {
        id: closeTimer
        interval: motion.fast
        onTriggered: palette.closing = false
    }

    ScriptModel {
        id: resultModel
        values: palette.filteredItems()
    }

    function subsequencePenalty(haystack: string, query: string): int {
        let offset = 0;
        let previous = -1;
        let penalty = 0;
        for (let i = 0; i < query.length; i++) {
            const position = haystack.indexOf(query[i], offset);
            if (position < 0)
                return 10000;
            if (previous < 0)
                penalty += position * 3;
            else
                penalty += (position - previous - 1) * 2;
            previous = position;
            offset = position + 1;
        }
        return penalty + Math.min(40, haystack.length - query.length);
    }

    function score(item, query): int {
        const name = item.name.toLowerCase();
        const generic = (item.genericName || "").toLowerCase();
        const keywords = (item.keywords || []).map(keyword => keyword.toLowerCase());
        const binding = (item.key || "").toLowerCase();
        if (name === query)
            return 0;
        if (name.startsWith(query))
            return 10;
        if (name.split(/\s+/).some(word => word.startsWith(query)))
            return 15;
        if (name.includes(query))
            return 20;
        if (keywords.some(keyword => keyword === query))
            return 25;
        if (keywords.some(keyword => keyword.startsWith(query)))
            return 30;
        if (generic.startsWith(query))
            return 35;
        if (generic.includes(query))
            return 40;
        if (keywords.some(keyword => keyword.includes(query)))
            return 45;
        if (binding.includes(query))
            return 50;
        if (query.length < 2)
            return 10000;
        return Math.min(100 + subsequencePenalty(name, query), 180 + subsequencePenalty(generic, query));
    }

    function filteredItems(): var {
        const query = search.text.trim().toLowerCase();

        const symbolMode = query.match(/^(?:emoji|symbol|sym)(?:\s+(.*))?$/);
        if (symbolMode)
            return SymbolLibrary.search(symbolMode[1] || "");

        const clipboardMode = query.match(/^clip(?:\s+(.*))?$/);
        if (clipboardMode) {
            const searchText = (clipboardMode[1] || "").toLowerCase();
            return (clipboardPanel.entries || []).filter(entry => !searchText || entry.preview.toLowerCase().includes(searchText)).slice(0, 9).map((entry, index) => ({
                        kind: "clipboard",
                        name: entry.kind === "TEXT" ? "Clipboard text " + (index + 1) : "Clipboard image / data " + (index + 1),
                        genericName: entry.preview,
                        icon: "edit-paste",
                        key: "COPY",
                        entryId: entry.id
                    }));
        }

        const explicitCalculation = query.match(/^calc\s+(.+)$/);
        const expression = explicitCalculation ? explicitCalculation[1] : query;
        // Arithmetic works directly in search; other queries retain fuzzy app/action matching.
        const arithmeticQuery = /^[\d\s().+\-*/^]+$/.test(expression) && /\d/.test(expression) && /[+\-*/^]/.test(expression);
        if (explicitCalculation || arithmeticQuery) {
            const result = Calculator.calculate(expression);
            if (result !== null)
                return [
                    {
                        kind: "calculation",
                        name: "= " + result,
                        genericName: expression + " · Enter to copy",
                        icon: "accessories-calculator",
                        key: "COPY",
                        result: result
                    }
                ];
            if (explicitCalculation)
                return [];
        }

        const commandItems = (commands || []).map(command => ({
                    kind: "command",
                    name: command.name,
                    genericName: command.description || "Desktop action",
                    icon: command.icon || "system-run",
                    key: command.key || "",
                    commandId: command.id,
                    keywords: command.keywords || []
                }));

        const applicationItems = [...DesktopEntries.applications.values].map(entry => ({
                    kind: "application",
                    name: entry.name,
                    genericName: entry.genericName || entry.comment || "Application",
                    icon: entry.icon || "application-x-executable",
                    key: "",
                    desktopEntry: entry,
                    keywords: entry.keywords || []
                }));

        const items = commandItems.concat(applicationItems);

        if (query.length === 0)
            return items.slice(0, 9);

        return items.map(item => ({
                    entry: item,
                    relevance: score(item, query)
                })).filter(result => result.relevance < 10000).sort((a, b) => {
            const rank = a.relevance - b.relevance;
            if (rank !== 0)
                return rank;
            if (a.entry.kind !== b.entry.kind)
                return a.entry.kind === "command" ? -1 : 1;
            return a.entry.name.localeCompare(b.entry.name);
        }).slice(0, 9).map(result => result.entry);
    }

    function setLauncherSubmap(enabled: bool): void {
        Hyprland.dispatch(Hyprland.usingLua ? 'hl.dsp.submap("' + (enabled ? "launcher" : "reset") + '")' : "submap " + (enabled ? "launcher" : "reset"));
    }

    function show(): void {
        closeTimer.stop();
        closing = false;
        setLauncherSubmap(true);
        copyFeedback = "";
        clipboardQueried = false;
        awaitingClipboardCopy = false;
        // Preserve the query across dismissals, including after copying a result.
        // Reopening a clipboard search must refresh cliphist without a text edit.
        if (/^clip(?:\s|$)/i.test(search.text.trim())) {
            clipboardQueried = true;
            clipboardPanel.refresh();
        }
        open = true;
        if (resultModel.values.length === 0)
            results.currentIndex = -1;
        else if (results.currentIndex < 0 || results.currentIndex >= resultModel.values.length)
            results.currentIndex = 0;
        search.forceActiveFocus();
    }

    function hide(): void {
        open = false;
        setLauncherSubmap(false);

        if (motion.fast === 0) {
            closing = false;
        } else {
            closing = true;
            closeTimer.restart();
        }
    }

    function toggle(): void {
        if (open)
            hide();
        else
            show();
    }

    function launchIndex(index: int): void {
        if (!open || index < 0 || index >= resultModel.values.length)
            return;

        results.currentIndex = index;
        launchCurrent(false);
    }

    function launchCurrent(keepOpen: bool): void {
        if (results.currentIndex < 0 || results.currentIndex >= resultModel.values.length)
            return;

        const entry = resultModel.values[results.currentIndex];

        if (entry.kind === "clipboard") {
            copyOnSuccessClose = !keepOpen;
            awaitingClipboardCopy = clipboardPanel.copyEntry(entry.entryId, false);
            copyFeedback = awaitingClipboardCopy ? "COPYING" : "CLIPBOARD BUSY";
            return;
        }

        if (entry.kind === "calculation" || entry.kind === "symbol") {
            copyFeedback = "COPYING";
            copyOnSuccessClose = !keepOpen;
            calculationCopy.exec(["wl-copy", "--type", "text/plain", entry.result]);
            return;
        }

        if (!keepOpen)
            hide();

        if (entry.kind === "command")
            commandTriggered(entry.commandId);
        else if (entry.desktopEntry)
            entry.desktopEntry.execute();

        if (keepOpen)
            search.forceActiveFocus();
    }

    Rectangle {
        anchors.fill: parent
        color: theme.scrimStrong
        opacity: palette.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: motion.fast
                easing.type: palette.open ? motion.enterType : motion.exitType
                easing.bezierCurve: palette.open ? motion.enterCurve : motion.exitCurve
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: palette.hide()
        }
    }

    ShellSurface {
        id: card

        width: Math.min(palette.width - 80, 780)
        height: Math.min(palette.height - 120, 675)
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: Math.max(86, palette.height * 0.13)
        }

        theme: palette.theme
        motion: palette.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusPanel

        scale: palette.open ? 1 : theme.panelClosedScale
        opacity: palette.open ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: motion.normal
                easing.type: motion.enterType
                easing.bezierCurve: motion.enterCurve
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: motion.fast
                easing.type: motion.effectsType
                easing.bezierCurve: motion.effectsCurve
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: theme.spacing5

            Column {
                id: paletteIntro
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                spacing: theme.spacing1

                Text {
                    text: "COMMAND PALETTE · APPS / ACTIONS / CLIP / EMOJI / MATH"
                    color: theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontPanelEyebrow
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.7
                }
                Text {
                    text: "What do you want to do?"
                    color: theme.textStrong
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(24)
                    font.weight: Font.DemiBold
                }
            }

            SquircleSurface {
                id: searchBox

                height: 60
                anchors {
                    top: paletteIntro.bottom
                    topMargin: theme.spacing3
                    left: parent.left
                    right: parent.right
                }

                exponent: theme.squircleExponent
                cornerRadius: theme.radiusMedium
                fillColor: theme.expressiveSurfaceStrong
                borderColor: search.activeFocus ? theme.accent : theme.outline
                borderWidth: search.activeFocus ? theme.borderFocus : theme.borderThin

                Behavior on borderColor {
                    ColorAnimation {
                        duration: motion.fast
                        easing.type: motion.effectsType
                        easing.bezierCurve: motion.effectsCurve
                    }
                }

                Text {
                    id: prompt

                    anchors {
                        left: parent.left
                        leftMargin: theme.spacing4
                        verticalCenter: parent.verticalCenter
                    }

                    text: ">"
                    color: theme.accent
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(20)
                    font.weight: Font.Bold
                }

                TextInput {
                    id: search

                    anchors {
                        left: prompt.right
                        right: shortcutHint.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: theme.spacing3
                        rightMargin: theme.spacing3
                    }

                    color: theme.textStrong
                    selectionColor: theme.accent
                    selectedTextColor: theme.background
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(18)
                    clip: true

                    Text {
                        anchors.fill: parent
                        visible: search.text.length === 0
                        text: "Apps, actions, clip, emoji, 2*(3+4)…"
                        color: theme.textMuted
                        font: search.font
                        verticalAlignment: Text.AlignVCenter
                    }

                    onTextChanged: {
                        palette.copyFeedback = "";
                        if (/^clip(?:\s|$)/i.test(search.text.trim())) {
                            if (!palette.clipboardQueried) {
                                palette.clipboardQueried = true;
                                palette.clipboardPanel.refresh();
                            }
                        } else {
                            palette.clipboardQueried = false;
                        }
                        results.currentIndex = resultModel.values.length > 0 ? 0 : -1;
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab) {
                            results.forceActiveFocus();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            palette.hide();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            results.currentIndex = Math.min(resultModel.values.length - 1, results.currentIndex + 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            results.currentIndex = Math.max(0, results.currentIndex - 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            const keepOpen = (event.modifiers & Qt.ShiftModifier) !== 0;
                            palette.launchCurrent(keepOpen);
                            event.accepted = true;
                        }
                    }
                }

                KeyChord {
                    id: shortcutHint

                    anchors {
                        right: parent.right
                        rightMargin: theme.spacing4
                        verticalCenter: parent.verticalCenter
                    }

                    shortcut: runtime.shortcut("launcher.toggle")
                    fontFamily: runtime.fontMono
                    fontSize: theme.fontSize(11)
                    textColor: theme.textMuted
                }
            }

            ListView {
                id: results

                anchors {
                    top: searchBox.bottom
                    right: parent.right
                    bottom: footer.top
                    left: parent.left
                    topMargin: theme.spacing3
                    bottomMargin: theme.spacing3
                }

                model: resultModel
                spacing: theme.spacing1
                clip: true
                currentIndex: resultModel.values.length > 0 ? 0 : -1
                // Autorepeated navigation must be immediate; the focused
                // surface itself still animates its tonal state.
                highlightMoveDuration: 0
                highlightResizeDuration: 0

                Keys.priority: Keys.BeforeItem
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_I || event.key === Qt.Key_Slash) {
                        search.forceActiveFocus();
                    } else if (event.key === Qt.Key_Escape) {
                        palette.hide();
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        results.currentIndex = Math.min(resultModel.values.length - 1, results.currentIndex + 1);
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        results.currentIndex = Math.max(0, results.currentIndex - 1);
                    } else if (event.key === Qt.Key_U || event.key === Qt.Key_D) {
                        const rows = Math.max(1, Math.floor(results.height / (57 + results.spacing) / 2));
                        results.currentIndex = Math.max(0, Math.min(resultModel.values.length - 1, results.currentIndex + (event.key === Qt.Key_D ? rows : -rows)));
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        palette.launchCurrent((event.modifiers & Qt.ShiftModifier) !== 0);
                    } else {
                        return;
                    }
                    event.accepted = true;
                }

                highlight: SquircleSurface {
                    exponent: theme.squircleExponent
                    cornerRadius: theme.radiusMedium
                    fillColor: theme.selectionFill
                    borderColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28)
                    borderWidth: theme.borderThin
                }

                delegate: Item {
                    id: result

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: 57

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: theme.spacing3
                            rightMargin: theme.spacing3
                        }
                        spacing: theme.spacing3

                        SquircleSurface {
                            width: 36
                            height: 36
                            anchors.verticalCenter: parent.verticalCenter
                            exponent: theme.squircleExponent
                            cornerRadius: theme.radiusSmall
                            fillColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.12)
                            borderColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.36)
                            borderWidth: theme.borderThin

                            Text {
                                anchors.centerIn: parent
                                text: result.index + 1
                                color: theme.accent
                                font.family: runtime.fontMono
                                font.pixelSize: theme.fontSize(11)
                                font.weight: Font.Bold
                            }
                        }

                        Item {
                            width: 36
                            height: parent.height

                            Image {
                                visible: !modelData.glyph
                                anchors.centerIn: parent
                                width: 29
                                height: 29
                                source: modelData.icon ? Quickshell.iconPath(modelData.icon, "application-x-executable") : Quickshell.iconPath("application-x-executable")
                                sourceSize.width: width
                                sourceSize.height: height
                                asynchronous: true
                                fillMode: Image.PreserveAspectFit
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !!modelData.glyph
                                text: modelData.glyph || ""
                                color: theme.textStrong
                                font.pixelSize: theme.fontSize(24)
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(90, parent.width - 240)
                            spacing: 1

                            Text {
                                width: parent.width
                                text: modelData.name
                                color: theme.textStrong
                                font.family: runtime.fontMono
                                font.pixelSize: theme.fontSize(14)
                                font.weight: result.ListView.isCurrentItem ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: modelData.genericName && modelData.genericName.length > 0
                                text: modelData.genericName
                                color: theme.textMuted
                                font.family: runtime.fontMono
                                font.pixelSize: theme.fontSize(11)
                                elide: Text.ElideRight
                            }
                        }

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 122
                            height: parent.height

                            KeyChord {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                shortcut: result.modelData.key.length > 0 ? result.modelData.key : (result.ListView.isCurrentItem ? "↵ RUN" : "")
                                fontFamily: runtime.fontMono
                                fontSize: theme.fontSize(11)
                                textColor: theme.accent
                            }
                        }
                    }

                    StateLayer {
                        theme: card.theme
                        motion: card.motion
                        cornerRadius: card.theme.radiusMedium
                        // Do not select a new row when search results move beneath a stationary pointer.
                        onPositionChanged: results.currentIndex = result.index
                        onActivated: {
                            results.currentIndex = result.index;
                            palette.launchCurrent(false);
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: resultModel.values.length === 0
                    text: "NO MATCHES"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(12)
                    font.letterSpacing: 1.5
                }
            }

            Row {
                id: footer

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                Text {
                    text: palette.copyFeedback || resultModel.values.length + " RESULTS"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(10)
                    font.letterSpacing: 1.2
                }

                Item {
                    width: parent.width - parent.children[0].width - hints.width
                    height: 1
                }

                Text {
                    id: hints
                    text: search.activeFocus ? "TYPE TO SEARCH  ·  TAB NAV  ·  ↑↓ SELECT  ·  ↵ OPEN  ·  ⇧ESC CLOSE" : "J/K SELECT  ·  U/D PAGE  ·  / SEARCH  ·  ↵ OPEN  ·  ESC  ·  ⇧ESC CLOSE"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(10)
                    font.letterSpacing: 0.7
                }
            }
        }
    }
}
