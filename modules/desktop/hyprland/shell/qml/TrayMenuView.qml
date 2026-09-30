import QtQuick
import Quickshell

Item {
    id: view

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

    property bool open: false
    property var stack: []
    property int selectedIndex: 0

    readonly property var currentHandle: open && stack.length > 0
        ? stack[stack.length - 1].handle
        : null
    readonly property string currentTitle: open && stack.length > 0
        ? stack[stack.length - 1].label
        : "Tray"
    readonly property var items: opener.children ? opener.children.values : []
    readonly property int itemCount: items.length

    visible: open

    QsMenuOpener {
        id: opener
        menu: view.currentHandle

        onChildrenChanged: Qt.callLater(view.selectFirst)
    }

    function selectable(index: int): bool {
        if (index < 0 || index >= items.length)
            return false;

        const entry = items[index];
        return !entry.isSeparator && entry.enabled;
    }

    function selectFirst(): void {
        for (let index = 0; index < items.length; index++) {
            if (selectable(index)) {
                selectedIndex = index;
                return;
            }
        }

        selectedIndex = 0;
    }

    function moveSelection(delta: int): void {
        if (items.length === 0)
            return;

        let candidate = selectedIndex;
        for (let step = 0; step < items.length; step++) {
            candidate = (candidate + delta + items.length) % items.length;
            if (selectable(candidate)) {
                selectedIndex = candidate;
                menuList.positionViewAtIndex(candidate, ListView.Contain);
                return;
            }
        }
    }

    function openFor(item): void {
        if (!item || !item.hasMenu)
            return;

        stack = [{
            handle: item.menu,
            label: item.title || item.id || "Tray"
        }];
        selectedIndex = 0;
        open = true;
        Qt.callLater(selectFirst);
    }

    function closeMenu(): void {
        open = false;
        stack = [];
        selectedIndex = 0;
    }

    function goBack(): void {
        if (stack.length <= 1) {
            closeMenu();
            return;
        }

        const next = [...stack];
        next.pop();
        stack = next;
        selectedIndex = 0;
        Qt.callLater(selectFirst);
    }

    function activateSelected(): void {
        if (!selectable(selectedIndex))
            return;

        const entry = items[selectedIndex];

        if (entry.hasChildren) {
            stack = [...stack, {
                handle: entry,
                label: entry.text || "Submenu"
            }];
            selectedIndex = 0;
            Qt.callLater(selectFirst);
            return;
        }

        entry.triggered();
        closeMenu();
    }

    Column {
        id: header

        width: parent.width
        spacing: theme.spacing1

        Text {
            text: "TRAY MENU // " + stack.map(level => level.label.toUpperCase()).join(" / ")
            color: theme.accent
            font.family: runtime.fontMono
            font.pixelSize: theme.fontSubpanelEyebrow
            font.weight: Font.DemiBold
            font.letterSpacing: 1.4
            elide: Text.ElideMiddle
            width: parent.width
        }

        Text {
            text: currentTitle
            color: theme.textStrong
            font.family: runtime.fontSans
            font.pixelSize: theme.fontSubpanelTitle
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            width: parent.width
        }

        Text {
            text: "↑↓ select  ·  Enter open  ·  Backspace back  ·  Esc back"
            color: theme.textMuted
            font.family: runtime.fontMono
            font.pixelSize: 9
        }
    }

    ListView {
        id: menuList

        anchors {
            top: header.bottom
            right: parent.right
            bottom: footer.top
            left: parent.left
            topMargin: theme.spacing4
            bottomMargin: theme.spacing3
        }

        model: view.items
        spacing: 4
        clip: true
        currentIndex: view.selectedIndex
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: entryDelegate

            required property var modelData
            required property int index

            width: ListView.view.width
            height: modelData.isSeparator ? 12 : 42

            Rectangle {
                visible: modelData.isSeparator
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                height: 1
                color: theme.outline
                opacity: 0.72
            }

            SquircleSurface {
                visible: !modelData.isSeparator
                anchors.fill: parent

                exponent: theme.squircleExponent
                cornerRadius: theme.radiusSmall
                fillColor: entryDelegate.index === view.selectedIndex
                    ? theme.focusFill
                    : "transparent"
                borderColor: entryDelegate.index === view.selectedIndex
                    ? theme.accent
                    : "transparent"
                borderWidth: entryDelegate.index === view.selectedIndex
                    ? theme.borderFocus
                    : theme.borderThin
                opacity: modelData.enabled ? 1 : 0.42

                MouseArea {
                    anchors.fill: parent
                    enabled: modelData.enabled

                    onClicked: {
                        view.selectedIndex = entryDelegate.index;
                        view.activateSelected();
                    }
                }

                Row {
                    anchors {
                        fill: parent
                        leftMargin: theme.spacing3
                        rightMargin: theme.spacing3
                    }
                    spacing: theme.spacing2

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.icon.length > 0
                        width: 20
                        height: 20
                        source: modelData.icon.length > 0
                            ? modelData.icon
                            : Quickshell.iconPath("application-x-executable")
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.buttonType !== QsMenuButtonType.None
                        text: modelData.checkState === Qt.Checked
                            ? (modelData.buttonType === QsMenuButtonType.RadioButton ? "●" : "✓")
                            : "○"
                        color: theme.accent
                        font.family: runtime.fontMono
                        font.pixelSize: 11
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                            - (modelData.icon.length > 0 ? 20 + parent.spacing : 0)
                            - (modelData.buttonType !== QsMenuButtonType.None ? 18 + parent.spacing : 0)
                            - (modelData.hasChildren ? 18 : 0)
                        text: modelData.text
                        color: theme.text
                        font.family: runtime.fontSans
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.hasChildren
                        text: "›"
                        color: theme.textMuted
                        font.family: runtime.fontMono
                        font.pixelSize: 16
                    }
                }
            }
        }
    }

    Row {
        id: footer

        anchors {
            right: parent.right
            bottom: parent.bottom
        }
        spacing: theme.spacing4

        Text {
            text: itemCount + " ENTRIES"
            color: theme.textMuted
            font.family: runtime.fontMono
            font.pixelSize: 9
            font.letterSpacing: 1
        }

        Text {
            text: stack.length > 1 ? "BACKSPACE  UP" : "BACKSPACE  TRAY"
            color: theme.accent
            font.family: runtime.fontMono
            font.pixelSize: 9
            font.letterSpacing: 1
        }
    }
}
