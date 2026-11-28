pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: flow
    default property alias actions: body.data
    property real spacing: 8
    property bool fillWidth: false
    implicitHeight: layout.height
    height: implicitHeight

    readonly property var rows: {
        const rows = [];
        let row = [], widthUsed = 0;
        const limit = Math.max(1, flow.width);
        for (const item of body.children) {
            const preferredWidth = flow.fillWidth ? Math.min(limit, item.implicitWidth) : item.width;
            if (!item.visible || preferredWidth <= 0 || (!flow.fillWidth && item.height <= 0))
                continue;
            if (row.length && widthUsed + flow.spacing + preferredWidth > limit) {
                rows.push({
                    items: row,
                    width: widthUsed
                });
                row = [];
                widthUsed = 0;
            }
            widthUsed += (row.length ? flow.spacing : 0) + preferredWidth;
            row.push({
                item,
                preferredWidth
            });
        }
        if (row.length)
            rows.push({
                items: row,
                width: widthUsed
            });
        return rows;
    }

    readonly property var layout: {
        const positions = [];
        let y = 0;
        for (const current of flow.rows) {
            const rowHeight = Math.max(...current.items.map(entry => entry.item.height));
            let x = flow.fillWidth ? 0 : Math.max(0, (flow.width - current.width) / 2);
            for (const entry of current.items) {
                const item = entry.item;
                const itemWidth = flow.actionWidth(item);
                positions.push({
                    item: item,
                    x: x,
                    width: itemWidth,
                    y: y + (rowHeight - item.height) / 2
                });
                x += itemWidth + flow.spacing;
            }
            y += rowHeight + flow.spacing;
        }
        return {
            positions: positions,
            height: Math.max(0, y - flow.spacing)
        };
    }

    function actionWidth(item: Item): real {
        if (!fillWidth)
            return item.width;
        for (const row of rows) {
            const entry = row.items.find(candidate => candidate.item === item);
            if (entry) {
                const preferredTotal = row.width - (row.items.length - 1) * spacing;
                return entry.preferredWidth + Math.max(0, width - row.width) * entry.preferredWidth / preferredTotal;
            }
        }
        return Math.min(width, item.implicitWidth);
    }

    Item {
        id: body
        anchors.fill: parent
    }
    Repeater {
        model: flow.layout.positions
        delegate: Item {
            id: placement
            required property var modelData
            Binding {
                target: placement.modelData.item
                property: "x"
                value: placement.modelData.x
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: placement.modelData.item
                property: "y"
                value: placement.modelData.y
                restoreMode: Binding.RestoreNone
            }
        }
    }
}
