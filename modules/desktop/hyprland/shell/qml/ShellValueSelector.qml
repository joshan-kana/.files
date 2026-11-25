pragma ComponentBehavior: Bound
import QtQuick
import "DesktopIcons.js" as DesktopIcons

// A single-choice field with an in-panel menu. The caller owns navigation
// scope and the actual value; the list has no independent settings state.
Column {
    id: selector
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property string title
    required property string shortcut
    required property string confirmShortcut
    property var options: []
    property var disabledIndices: []
    property bool highlighted: false
    property bool showField: true
    readonly property bool canChoose: options.some((value, index) => index !== selectedIndex && !disabledIndices.includes(index))
    onCanChooseChanged: if (!canChoose)
        cancel()

    onOptionsChanged: {
        if (!canChoose)
            cancel();
        else
            highlightedIndex = Math.max(0, Math.min(options.length - 1, highlightedIndex));
    }
    property int selectedIndex: -1
    property int highlightedIndex: 0
    property bool expanded: false
    signal chosen(int index)
    signal opened

    spacing: theme.spacing1

    function toggle(): void {
        if (canChoose && enabled)
            field.trigger();
    }
    function cancel(): bool {
        if (!expanded)
            return false;
        expanded = false;
        return true;
    }
    onEnabledChanged: if (!enabled)
        cancel()
    function moveHighlight(delta: int): void {
        let next = highlightedIndex + delta;
        while (next >= 0 && next < options.length && disabledIndices.includes(next))
            next += delta;
        if (next >= 0 && next < options.length)
            highlightedIndex = next;
    }
    function commit(): void {
        if (expanded)
            (menuRows.itemAt(highlightedIndex) as ShellAction)?.trigger();
    }
    onHighlightedIndexChanged: {
        const row = menuRows.itemAt(highlightedIndex);
        if (expanded && row) {
            if (row.y < menuScroll.contentY)
                menuScroll.contentY = row.y;
            else if (row.y + row.height > menuScroll.contentY + menuScroll.height)
                menuScroll.contentY = Math.max(0, row.y + row.height - menuScroll.height);
        }
    }

    ShellText {
        width: parent.width
        runtime: selector.runtime
        theme: selector.theme
        text: selector.title
        textRole: ShellText.Supporting
    }
    ShellSurface {
        visible: selector.showField && !selector.canChoose
        width: parent.width
        height: visible ? Math.max(selector.theme.fontSize(44), singleValue.implicitHeight + selector.theme.spacing2 * 2) : 0
        theme: selector.theme
        motion: selector.motion
        surfaceLayer: ShellSurface.Group
        cornerRadius: selector.theme.radiusMedium
        ShellText {
            id: singleValue
            width: Math.max(1, parent.width - selector.theme.spacing3 * 2)
            anchors.centerIn: parent
            runtime: selector.runtime
            theme: selector.theme
            text: selector.options[selector.selectedIndex] || "Unavailable"
            textRole: ShellText.Readback
            wrapMode: Text.WordWrap
        }
    }
    ShellAction {
        id: field
        visible: selector.showField && selector.canChoose
        width: parent.width
        height: Math.max(selector.theme.fontSize(44), implicitHeight)
        runtime: selector.runtime
        theme: selector.theme
        motion: selector.motion
        compact: true
        horizontalCompact: true
        restingRadius: selector.theme.radiusMedium
        icon: DesktopIcons.actionGlyph(selector.expanded ? "collapse" : "expand")
        title: selector.options[selector.selectedIndex] || "Unavailable"
        shortcut: selector.expanded ? "" : selector.shortcut
        active: selector.expanded
        highlighted: selector.highlighted && !selector.expanded
        actionFill: active ? selector.theme.choiceFill(activeColor) : selector.theme.expressiveSurfaceStrong
        actionForeground: active ? selector.theme.choiceForeground(activeColor) : selector.theme.readableColor(activeColor, actionFill)
        activeColor: selector.theme.choiceColor
        enabled: selector.canChoose
        Accessible.description: selector.title
        onActivated: {
            selector.expanded = !selector.expanded;
            if (selector.expanded) {
                selector.opened();
                selector.highlightedIndex = Math.max(0, selector.selectedIndex >= 0 ? selector.selectedIndex : selector.options.findIndex((value, index) => !selector.disabledIndices.includes(index)));
                Qt.callLater(() => {
                    const row = menuRows.itemAt(selector.highlightedIndex);
                    if (row)
                        menuScroll.contentY = Math.max(0, Math.min(row.y, menuScroll.contentHeight - menuScroll.height));
                });
            }
        }
    }
    ShellSurface {
        width: parent.width
        visible: selector.expanded
        height: visible ? Math.min(menuContent.implicitHeight + selector.theme.spacing2 * 2, selector.theme.fontSize(240)) : 0
        theme: selector.theme
        motion: selector.motion
        surfaceLayer: ShellSurface.Group
        cornerRadius: selector.theme.radiusMedium
        Flickable {
            id: menuScroll
            anchors.fill: parent
            anchors.margins: selector.theme.spacing2
            contentWidth: width
            contentHeight: menuContent.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: menuContent
                width: menuScroll.width
                spacing: selector.theme.spacing1
                Repeater {
                    id: menuRows
                    model: selector.expanded ? selector.options : []
                    delegate: ShellChoice {
                        required property int index
                        required property string modelData
                        width: menuContent.width
                        height: Math.max(selector.theme.fontSize(40), implicitHeight)
                        runtime: selector.runtime
                        theme: selector.theme
                        motion: selector.motion
                        compact: true
                        horizontalCompact: true
                        title: modelData
                        icon: index === selector.selectedIndex ? DesktopIcons.actionGlyph("confirm") : ""
                        joined: false
                        enabled: !selector.disabledIndices.includes(index)
                        active: index === selector.selectedIndex
                        highlighted: index === selector.highlightedIndex
                        activeColor: selector.theme.choiceColor
                        shortcut: highlighted ? selector.confirmShortcut : ""
                        onActivated: {
                            selector.expanded = false;
                            selector.chosen(index);
                        }
                    }
                }
            }
        }
    }
}
