import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: palette

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property var commands: []
    signal commandTriggered(string commandId)

    property bool open: false
    property bool closing: false

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

    Timer {
        id: closeTimer
        interval: motion.fast
        onTriggered: palette.closing = false
    }

    ScriptModel {
        id: resultModel
        values: palette.filteredItems()
    }

    function score(item, query): int {
        const name = item.name.toLowerCase();
        const generic = (item.genericName || "").toLowerCase();

        if (name === query)
            return 0;
        if (name.startsWith(query))
            return 1;
        if (name.includes(query))
            return 2;
        if ((item.keywords || []).some(keyword => keyword.toLowerCase() === query))
            return 3;
        if (generic.startsWith(query))
            return 4;
        if (generic.includes(query))
            return 5;

        return 10;
    }

    function filteredItems(): var {
        const query = search.text.trim().toLowerCase();

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

        return items.filter(item => {
            const haystack = [item.name, item.genericName || "", item.key || "", ...(item.keywords || [])].join(" ").toLowerCase();

            return haystack.includes(query);
        }).sort((a, b) => {
            const rank = score(a, query) - score(b, query);
            if (rank !== 0)
                return rank;

            if (a.kind !== b.kind)
                return a.kind === "command" ? -1 : 1;

            return a.name.localeCompare(b.name);
        }).slice(0, 9);
    }

    function setLauncherSubmap(enabled: bool): void {
        Hyprland.dispatch(Hyprland.usingLua ? 'hl.dsp.submap("' + (enabled ? "launcher" : "reset") + '")' : "submap " + (enabled ? "launcher" : "reset"));
    }

    function show(): void {
        closeTimer.stop();
        closing = false;
        setLauncherSubmap(true);
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
        height: Math.min(palette.height - 120, 610)
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
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: motion.fast
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: theme.spacing5

            SquircleSurface {
                id: searchBox

                height: 58
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }

                exponent: theme.squircleExponent
                cornerRadius: theme.radiusMedium
                fillColor: theme.surfaceRaised
                borderColor: search.activeFocus ? theme.accent : theme.outline
                borderWidth: search.activeFocus ? theme.borderFocus : theme.borderThin

                Behavior on borderColor {
                    ColorAnimation {
                        duration: motion.fast
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
                        text: "Search apps and actions…"
                        color: theme.textMuted
                        font: search.font
                        verticalAlignment: Text.AlignVCenter
                    }

                    onTextChanged: results.currentIndex = resultModel.values.length > 0 ? 0 : -1

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

                Text {
                    id: shortcutHint

                    anchors {
                        right: parent.right
                        rightMargin: theme.spacing4
                        verticalCenter: parent.verticalCenter
                    }

                    text: runtime.shortcut("launcher.toggle")
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(10)
                    font.letterSpacing: 0.8
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
                highlightMoveDuration: motion.fast
                highlightResizeDuration: motion.fast

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
                        const rows = Math.max(1, Math.floor(results.height / (48 + results.spacing) / 2));
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
                    fillColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.13)
                    borderColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28)
                    borderWidth: theme.borderThin
                }

                delegate: Item {
                    id: result

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: 48

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: theme.spacing3
                            rightMargin: theme.spacing3
                        }
                        spacing: theme.spacing3

                        SquircleSurface {
                            width: 28
                            height: 28
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
                            width: 30
                            height: parent.height

                            Image {
                                anchors.centerIn: parent
                                width: 24
                                height: 24
                                source: modelData.icon ? Quickshell.iconPath(modelData.icon, "application-x-executable") : Quickshell.iconPath("application-x-executable")
                                sourceSize.width: width
                                sourceSize.height: height
                                asynchronous: true
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 190
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

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 86
                            text: modelData.key.length > 0 ? modelData.key : (result.ListView.isCurrentItem ? "↵  RUN" : "")
                            horizontalAlignment: Text.AlignRight
                            color: theme.accent
                            font.family: runtime.fontMono
                            font.pixelSize: theme.fontSize(10)
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.8
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        // Do not select a new row when search results move beneath a stationary pointer.
                        onPositionChanged: results.currentIndex = result.index
                        onClicked: {
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
                    text: resultModel.values.length + " RESULTS"
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
                    text: search.activeFocus ? "TYPE TO SEARCH  ·  TAB NAV  ·  ↑↓ SELECT  ·  ↵ OPEN" : "J/K SELECT  ·  U/D HALF PAGE  ·  / SEARCH  ·  ↵ OPEN  ·  ESC"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(10)
                    font.letterSpacing: 0.7
                }
            }
        }
    }
}
