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
    property int groupSpacing: theme.spacing2

    implicitHeight: hintRows.implicitHeight

    // Measure actual keycaps using the same component and font settings as
    // the visible hints. Estimating widths from string lengths drifts when
    // font scale, symbols or modifier chords change.
    Item {
        visible: false
        Repeater {
            id: measuredHints
            model: strip.hints
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
        const count = measuredHints.count;
        for (let i = 0; i < count; i++) {
            const hint = measuredHints.itemAt(i);
            if (!hint || !hint.visible)
                continue;
            const width = hint.implicitWidth;
            if (entries.length > 0 && occupied + strip.groupSpacing + width > limit) {
                rows.push(entries);
                entries = [];
                occupied = 0;
            }
            occupied += (entries.length > 0 ? strip.groupSpacing : 0) + width;
            entries.push(strip.hints[i]);
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
                anchors.horizontalCenter: parent.horizontalCenter
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
