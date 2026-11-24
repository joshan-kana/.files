pragma ComponentBehavior: Bound
import QtQuick

// A width-aware set of shortcut groups. Each wrapped row has its own
// optical centre, and a keycap is never detached from its action label.
Item {
    id: strip
    required property RuntimeConfig runtime
    required property Theme theme
    property var hints: []
    property bool compact: true
    property bool trailing: false
    property int groupSpacing: theme.spacing2

    property var measuredItems: []
    implicitHeight: hintRows.implicitHeight

    // Measure actual keycaps using the same component and font settings as
    // the visible hints. Estimating widths from string lengths drifts when
    // font scale, symbols or modifier chords change.
    Item {
        // Keep measure delegates instantiated and logically visible; make
        // only the measurement container transparent and non-interactive.
        // Hiding its parent makes Qt report every child as invisible.
        opacity: 0
        enabled: false
        width: 0
        height: 0
        Repeater {
            id: measuredHints
            model: strip.hints
            onItemAdded: (index, item) => {
                const next = strip.measuredItems.slice();
                next.splice(index, 0, item);
                strip.measuredItems = next;
            }
            onItemRemoved: (index, item) => strip.measuredItems = strip.measuredItems.filter(entry => entry !== item)
            delegate: KeyHint {
                required property var modelData
                runtime: strip.runtime
                theme: strip.theme
                shortcut: modelData.shortcut
                label: modelData.label
                compact: strip.compact
                available: modelData.available !== false
                visible: modelData.visible === undefined || modelData.visible
            }
        }
    }

    readonly property var wrappedRows: {
        const rows = [];
        let entries = [];
        let occupied = 0;
        const limit = Math.max(1, strip.width);
        for (const hint of strip.measuredItems) {
            if (!hint || hint.modelData.visible === false)
                continue;
            const width = hint.implicitWidth;
            if (entries.length > 0 && occupied + strip.groupSpacing + width > limit) {
                rows.push(entries);
                entries = [];
                occupied = 0;
            }
            occupied += (entries.length > 0 ? strip.groupSpacing : 0) + width;
            entries.push(hint.modelData);
        }
        if (entries.length > 0)
            rows.push(entries);
        return rows;
    }

    Column {
        id: hintRows
        width: parent.width
        spacing: strip.theme.spacing1
        Repeater {
            model: strip.wrappedRows
            delegate: Row {
                id: hintRow
                required property var modelData
                x: strip.trailing ? Math.max(0, parent.width - implicitWidth) : (parent.width - implicitWidth) / 2
                spacing: strip.groupSpacing
                Repeater {
                    model: hintRow.modelData
                    delegate: KeyHint {
                        required property var modelData
                        runtime: strip.runtime
                        theme: strip.theme
                        shortcut: modelData.shortcut
                        label: modelData.label
                        compact: strip.compact
                        emphasized: modelData.emphasized === true
                        available: modelData.available !== false
                    }
                }
            }
        }
    }
}
