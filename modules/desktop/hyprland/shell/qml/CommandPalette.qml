import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: palette

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

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
        id: applicationModel
        values: palette.filteredApplications()
    }

    function score(entry, query): int {
        const name = entry.name.toLowerCase();
        const generic = (entry.genericName || "").toLowerCase();

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

    function filteredApplications(): var {
        const query = search.text.trim().toLowerCase();
        const applications = [...DesktopEntries.applications.values];

        if (query.length === 0)
            return applications
                .sort((a, b) => a.name.localeCompare(b.name))
                .slice(0, 9);

        return applications
            .filter(entry => {
                const haystack = [
                    entry.name,
                    entry.genericName || "",
                    entry.comment || "",
                    ...(entry.keywords || [])
                ].join(" ").toLowerCase();

                return haystack.includes(query);
            })
            .sort((a, b) => {
                const rank = score(a, query) - score(b, query);
                return rank !== 0 ? rank : a.name.localeCompare(b.name);
            })
            .slice(0, 9);
    }

    function show(): void {
        closeTimer.stop();
        closing = false;
        open = true;
        search.text = "";
        results.currentIndex = applicationModel.values.length > 0 ? 0 : -1;
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
        if (results.currentIndex < 0 || results.currentIndex >= applicationModel.values.length)
            return;

        const entry = applicationModel.values[results.currentIndex];
        hide();
        entry.execute();
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
                        text: "Search applications…"
                        color: theme.textMuted
                        font: search.font
                        verticalAlignment: Text.AlignVCenter
                    }

                    onTextChanged: results.currentIndex = applicationModel.values.length > 0 ? 0 : -1

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            palette.hide();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            results.currentIndex = Math.min(applicationModel.values.length - 1, results.currentIndex + 1);
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

                model: applicationModel
                spacing: 4
                clip: true
                currentIndex: applicationModel.values.length > 0 ? 0 : -1
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
                            text: result.ListView.isCurrentItem ? "↵  OPEN" : ""
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
                    visible: applicationModel.values.length === 0
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
                    text: applicationModel.values.length + " RESULTS"
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
