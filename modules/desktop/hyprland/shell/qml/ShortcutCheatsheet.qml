import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

    property bool open: false
    property bool closing: false
    property string query: ""
    readonly property var sections: buildSections(query)
    readonly property int filteredBindingCount: countBindings(sections)

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

    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Timer {
        id: closeTimer
        interval: motion.fast
        onTriggered: window.closing = false
    }

    function buildSections(searchQuery: string): var {
        const groups = [];
        const byName = {};
        const normalized = (searchQuery || "").trim().toLowerCase();

        for (const binding of runtime.keybindings || []) {
            const section = String(binding.section || "");
            const key = String(binding.key || "");
            const description = String(binding.description || "");
            const haystack = (section + " " + key + " " + description).toLowerCase();

            if (normalized.length > 0 && haystack.indexOf(normalized) === -1)
                continue;

            if (!byName[section]) {
                const group = {
                    title: section,
                    items: []
                };
                byName[section] = group;
                groups.push(group);
            }
            byName[section].items.push(binding);
        }

        return groups;
    }

    function countBindings(groups: var): int {
        let count = 0;
        for (const group of groups || [])
            count += group.items.length;
        return count;
    }

    function handleNavigation(event: var): void {
        if (event.key === Qt.Key_Tab) {
            if (search.activeFocus)
                keySink.forceActiveFocus();
            else
                search.forceActiveFocus();
            event.accepted = true;
        } else if (!search.activeFocus && (event.key === Qt.Key_I || event.key === Qt.Key_Slash)) {
            search.forceActiveFocus();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            if (search.text.length > 0) {
                search.text = "";
                flick.contentY = 0;
                search.forceActiveFocus();
            } else {
                window.hide();
            }
            event.accepted = true;
        } else if ((event.key === Qt.Key_Up || (!search.activeFocus && event.key === Qt.Key_K))) {
            flick.contentY = Math.max(0, flick.contentY - 72);
            event.accepted = true;
        } else if ((event.key === Qt.Key_Down || (!search.activeFocus && event.key === Qt.Key_J))) {
            flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + 72);
            event.accepted = true;
        } else if ((event.key === Qt.Key_PageUp || (!search.activeFocus && event.key === Qt.Key_U))) {
            flick.contentY = Math.max(0, flick.contentY - flick.height * (event.key === Qt.Key_U ? 0.5 : 0.8));
            event.accepted = true;
        } else if ((event.key === Qt.Key_PageDown || (!search.activeFocus && event.key === Qt.Key_D))) {
            flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + flick.height * (event.key === Qt.Key_D ? 0.5 : 0.8));
            event.accepted = true;
        }
    }

    function show(): void {
        closeTimer.stop();
        closing = false;
        search.text = "";
        flick.contentY = 0;
        open = true;
        search.forceActiveFocus();
    }

    function hide(): void {
        if (!open)
            return;

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

    Rectangle {
        anchors.fill: parent
        color: theme.scrimHeavy
        opacity: window.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: motion.fast
                easing.type: window.open ? motion.enterType : motion.exitType
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: window.hide()
        }
    }

    ShellSurface {
        id: card

        width: Math.min(window.width - 120, 1380)
        height: Math.min(window.height - 120, 820)
        anchors.centerIn: parent

        theme: window.theme
        motion: window.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusPanel

        scale: window.open ? 1 : theme.panelClosedScale

        Behavior on scale {
            NumberAnimation {
                duration: motion.normal
                easing.type: motion.enterType
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: theme.spacing5

            Item {
                id: header
                width: parent.width
                height: Math.max(title.implicitHeight, headerHint.implicitHeight)

                Text {
                    id: title
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Shortcuts"
                    color: theme.textStrong
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(28)
                    font.weight: Font.DemiBold
                }

                Text {
                    id: headerHint
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: runtime.shortcut("shortcuts.toggle") + "   ·   ESC CLOSE"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(10)
                    font.letterSpacing: 0.6
                }
            }

            ShellSurface {
                id: searchBox

                theme: window.theme
                motion: window.motion
                surfaceLayer: ShellSurface.Group

                height: 42
                anchors {
                    top: header.bottom
                    right: parent.right
                    left: parent.left
                    topMargin: theme.spacing3
                }

                outlined: search.activeFocus
                borderColor: search.activeFocus ? theme.accent : theme.subtleBorder
                cornerRadius: theme.radiusSmall

                Text {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: theme.spacing3
                    }
                    visible: search.text.length === 0
                    text: "Search shortcuts…"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(13)
                }

                TextInput {
                    id: search

                    anchors {
                        fill: parent
                        leftMargin: theme.spacing3
                        rightMargin: theme.spacing3
                    }
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: theme.text
                    selectionColor: theme.accent
                    selectedTextColor: theme.background
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(13)
                    onTextChanged: {
                        window.query = text;
                        flick.contentY = 0;
                    }
                    Keys.onPressed: event => window.handleNavigation(event)
                }
            }

            Flickable {
                id: flick
                anchors {
                    top: searchBox.bottom
                    right: parent.right
                    bottom: footer.top
                    left: parent.left
                    topMargin: theme.spacing4
                    bottomMargin: theme.spacing4
                }

                clip: true
                contentWidth: width
                contentHeight: sectionGrid.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Grid {
                    id: sectionGrid

                    width: parent.width
                    columns: width >= 1180 ? 3 : (width >= 760 ? 2 : 1)
                    columnSpacing: theme.spacing5
                    rowSpacing: theme.spacing5

                    Repeater {
                        model: window.sections

                        delegate: Column {
                            required property var modelData

                            width: (sectionGrid.width - sectionGrid.columnSpacing * (sectionGrid.columns - 1)) / sectionGrid.columns
                            spacing: theme.spacing2

                            Text {
                                text: modelData.title
                                color: theme.accent
                                font.family: runtime.fontMono
                                font.pixelSize: theme.fontSize(12)
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.6
                            }

                            Repeater {
                                model: modelData.items

                                delegate: Row {
                                    required property var modelData

                                    width: parent.width
                                    spacing: theme.spacing3

                                    ShellSurface {
                                        width: 142
                                        height: 28
                                        theme: window.theme
                                        motion: window.motion
                                        surfaceLayer: ShellSurface.Group
                                        cornerRadius: theme.radiusSmall

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.key
                                            color: theme.textStrong
                                            font.family: runtime.fontMono
                                            font.pixelSize: theme.fontSize(11)
                                            font.weight: Font.Medium
                                        }
                                    }

                                    Text {
                                        width: parent.width - 142 - parent.spacing
                                        anchors.verticalCenter: parent.children[0].verticalCenter
                                        text: modelData.description
                                        color: theme.text
                                        font.family: runtime.fontMono
                                        font.pixelSize: theme.fontSize(13)
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: flick
                visible: window.query.trim().length > 0 && window.filteredBindingCount === 0
                text: "No matching shortcuts"
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(14)
            }

            Rectangle {
                id: scrollTrack
                anchors {
                    top: flick.top
                    right: flick.right
                    bottom: flick.bottom
                }
                width: 3
                radius: 2
                color: theme.outline
                opacity: 0.28
                visible: flick.contentHeight > flick.height + 1

                Rectangle {
                    width: parent.width
                    height: Math.max(36, parent.height * Math.min(1, flick.height / flick.contentHeight))
                    y: {
                        const maxScroll = Math.max(0, flick.contentHeight - flick.height);
                        if (maxScroll === 0)
                            return 0;

                        return (parent.height - height) * Math.max(0, Math.min(1, flick.contentY / maxScroll));
                    }
                    radius: parent.radius
                    color: theme.accent
                    opacity: 0.82
                }
            }

            Item {
                id: footer
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    left: parent.left
                }
                height: Math.max(navigationHint.implicitHeight, footerMeta.implicitHeight)

                Text {
                    id: navigationHint
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    text: search.activeFocus ? "TYPE  SEARCH   TAB  NAV   PGUP/PGDN  PAGE" : "J/K  SCROLL   U/D  HALF PAGE   /  SEARCH   ESC  CLOSE"
                    color: theme.textMuted
                    font.family: runtime.fontMono
                    font.pixelSize: theme.fontSize(10)
                    font.letterSpacing: 0.4
                }

                Row {
                    id: footerMeta
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: theme.spacing3

                    Text {
                        text: window.filteredBindingCount + " / " + runtime.keybindings.length + " bindings"
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(12)
                    }

                    Text {
                        text: "TOGGLE " + runtime.shortcut("shortcuts.toggle")
                        color: theme.accent
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(12)
                        font.weight: Font.DemiBold
                    }
                }
            }

            FocusScope {
                id: keySink
                anchors.fill: parent
                focus: window.open

                Keys.onPressed: event => window.handleNavigation(event)
            }
        }
    }
}
