import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: palette

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

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
        if (generic.startsWith(query))
            return 3;
        if (generic.includes(query))
            return 4;

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

        return items
            .filter(item => {
                const haystack = [
                    item.name,
                    item.genericName || "",
                    item.key || "",
                    ...(item.keywords || [])
                ].join(" ").toLowerCase();

                return haystack.includes(query);
            })
            .sort((a, b) => {
                const rank = score(a, query) - score(b, query);
                if (rank !== 0)
                    return rank;

                if (a.kind !== b.kind)
                    return a.kind === "command" ? -1 : 1;

                return a.name.localeCompare(b.name);
            })
            .slice(0, 9);
    }

    function show(): void {
        closeTimer.stop();
        closing = false;
        open = true;
        search.text = "";
        results.currentIndex = resultModel.values.length > 0 ? 0 : -1;
        search.forceActiveFocus();
    }

    function hide(): void {
        open = false;

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

    function launchCurrent(): void {
        if (results.currentIndex < 0 || results.currentIndex >= resultModel.values.length)
            return;

        const entry = resultModel.values[results.currentIndex];
        hide();

        if (entry.kind === "command")
            commandTriggered(entry.commandId);
        else if (entry.desktopEntry)
            entry.desktopEntry.execute();
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.56)
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

    SquircleSurface {
        id: card

        width: Math.min(palette.width - 80, 780)
        height: Math.min(palette.height - 120, 610)
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: Math.max(86, palette.height * 0.13)
        }

        exponent: theme.squircleExponent
        cornerRadius: theme.radiusLarge
        fillColor: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.985)
        borderColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.42)
        borderWidth: 1

        scale: palette.open ? 1 : 0.965
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
            anchors.margins: theme.spacing4

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
                borderWidth: search.activeFocus ? 1.5 : 1

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
                    font.pixelSize: 20
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
                    font.family: runtime.fontSans
                    font.pixelSize: 18
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
                        if (event.key === Qt.Key_Escape) {
                            palette.hide();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            results.currentIndex = Math.min(resultModel.values.length - 1, results.currentIndex + 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            results.currentIndex = Math.max(0, results.currentIndex - 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            palette.launchCurrent();
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

                    text: "SUPER + SPACE"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: 10
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
                spacing: 4
                clip: true
                currentIndex: resultModel.values.length > 0 ? 0 : -1
                highlightMoveDuration: motion.fast
                highlightResizeDuration: motion.fast

                highlight: SquircleSurface {
                    exponent: theme.squircleExponent
                    cornerRadius: theme.radiusMedium
                    fillColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.13)
                    borderColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28)
                    borderWidth: 1
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
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 150
                            spacing: 1

                            Text {
                                width: parent.width
                                text: modelData.name
                                color: theme.textStrong
                                font.family: runtime.fontSans
                                font.pixelSize: 14
                                font.weight: result.ListView.isCurrentItem ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: modelData.genericName && modelData.genericName.length > 0
                                text: modelData.genericName
                                color: theme.textMuted
                                font.family: runtime.fontSans
                                font.pixelSize: 11
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
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.8
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: results.currentIndex = result.index
                        onClicked: {
                            results.currentIndex = result.index;
                            palette.launchCurrent();
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: resultModel.values.length === 0
                    text: "NO MATCHES"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: 12
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
                    font.pixelSize: 10
                    font.letterSpacing: 1.2
                }

                Item {
                    width: parent.width - parent.children[0].width - hints.width
                    height: 1
                }

                Text {
                    id: hints
                    text: "↑↓ NAVIGATE   ↵ OPEN   ESC CLOSE"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: 10
                    font.letterSpacing: 0.7
                }
            }
        }
    }
}
