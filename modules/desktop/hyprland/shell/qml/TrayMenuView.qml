pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Item {
    id: view

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property bool open: false
    property var stack: []
    property int selectedIndex: 0

    readonly property var currentHandle: open && stack.length > 0 ? stack[stack.length - 1].handle : null
    readonly property string currentTitle: open && stack.length > 0 ? stack[stack.length - 1].label : "Tray"
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

    function moveHalfPage(direction: int): void {
        const rowHeight = menuList.currentItem ? menuList.currentItem.height + menuList.spacing : 48;
        const steps = Math.max(1, Math.floor(menuList.height / Math.max(1, rowHeight) / 2));
        for (let i = 0; i < steps; i++)
            moveSelection(direction);
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

        stack = [
            {
                handle: item.menu,
                label: item.title || item.id || "Tray"
            }
        ];
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
            stack = [...stack,
                {
                    handle: entry,
                    label: entry.text || "Submenu"
                }
            ];
            selectedIndex = 0;
            Qt.callLater(selectFirst);
            return;
        }

        entry.triggered();
        closeMenu();
    }

    DetailHero {
        id: header
        width: parent.width
        runtime: view.runtime
        theme: view.theme
        motion: view.motion
        glyph: "◇"
        eyebrow: "Tray / " + view.stack.map(level => level.label.toUpperCase()).join(" / ")
        title: view.currentTitle
        detail: "↑↓ Select · Enter Open · Backspace Back · Esc Close"
    }

    ListView {
        id: menuList

        anchors {
            top: header.bottom
            right: parent.right
            bottom: footer.top
            left: parent.left
            topMargin: view.theme.spacing4
            bottomMargin: view.theme.spacing3
        }

        model: view.items
        spacing: view.theme.spacing1
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
                visible: entryDelegate.modelData.isSeparator
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                height: 1
                color: view.theme.outline
                opacity: 0.72
            }

            ShellSurface {
                visible: !entryDelegate.modelData.isSeparator
                anchors.fill: parent
                theme: view.theme
                motion: view.motion
                surfaceLayer: ShellSurface.Control
                selected: entryDelegate.index === view.selectedIndex
                cornerRadius: theme.radiusSmall
                opacity: entryDelegate.modelData.enabled ? 1 : 0.42

                Row {
                    anchors {
                        fill: parent
                        leftMargin: view.theme.spacing3
                        rightMargin: view.theme.spacing3
                    }
                    spacing: view.theme.spacing2

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: entryDelegate.modelData.icon.length > 0
                        width: 20
                        height: 20
                        source: entryDelegate.modelData.icon.length > 0 ? entryDelegate.modelData.icon : Quickshell.iconPath("application-x-executable")
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: entryDelegate.modelData.buttonType !== QsMenuButtonType.None
                        text: entryDelegate.modelData.checkState === Qt.Checked ? (entryDelegate.modelData.buttonType === QsMenuButtonType.RadioButton ? "●" : "✓") : "○"
                        color: view.theme.accent
                        font.family: view.runtime.fontMono
                        font.pixelSize: view.theme.fontSize(11)
                    }

                    MarqueeText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - (entryDelegate.modelData.icon.length > 0 ? 20 + parent.spacing : 0) - (entryDelegate.modelData.buttonType !== QsMenuButtonType.None ? 18 + parent.spacing : 0) - (entryDelegate.modelData.hasChildren ? 18 : 0)
                        text: entryDelegate.modelData.text
                        color: view.theme.text
                        font.family: view.runtime.fontMono
                        font.pixelSize: view.theme.fontSize(12)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: entryDelegate.modelData.hasChildren
                        text: "›"
                        color: view.theme.textMuted
                        font.family: view.runtime.fontMono
                        font.pixelSize: view.theme.fontSize(16)
                    }
                }

                StateLayer {
                    theme: view.theme
                    motion: view.motion
                    disabled: !entryDelegate.modelData.enabled
                    selected: entryDelegate.index === view.selectedIndex
                    cornerRadius: view.theme.radiusSmall
                    onActivated: {
                        view.selectedIndex = entryDelegate.index;
                        view.activateSelected();
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
        spacing: view.theme.spacing4

        Text {
            text: view.itemCount + " ENTRIES"
            color: view.theme.textMuted
            font.family: view.runtime.fontMono
            font.pixelSize: view.theme.fontSize(9)
            font.letterSpacing: 1
        }

        Text {
            text: view.stack.length > 1 ? "BACKSPACE  UP" : "BACKSPACE  TRAY"
            color: view.theme.accent
            font.family: view.runtime.fontMono
            font.pixelSize: view.theme.fontSize(9)
            font.letterSpacing: 1
        }
    }
}
