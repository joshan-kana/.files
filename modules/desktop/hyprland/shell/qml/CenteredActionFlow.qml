pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: flow
    default property alias actions: body.data
    property real spacing: 8
    implicitHeight: layout.height
    height: implicitHeight

    readonly property var layout: {
        const rows = [];
        let row = [], widthUsed = 0, rowHeight = 0;
        const limit = Math.max(1, flow.width);
        for (const item of body.children) {
            if (!item.visible || item.width <= 0 || item.height <= 0)
                continue;
            if (row.length && widthUsed + flow.spacing + item.width > limit) {
                rows.push({
                    items: row,
                    width: widthUsed,
                    height: rowHeight
                });
                row = [];
                widthUsed = 0;
                rowHeight = 0;
            }
            widthUsed += (row.length ? flow.spacing : 0) + item.width;
            rowHeight = Math.max(rowHeight, item.height);
            row.push(item);
        }
        if (row.length)
            rows.push({
                items: row,
                width: widthUsed,
                height: rowHeight
            });
        const positions = [];
        let y = 0;
        for (const current of rows) {
            let x = Math.max(0, (limit - current.width) / 2);
            for (const item of current.items) {
                positions.push({
                    item: item,
                    x: x,
                    y: y + (current.height - item.height) / 2
                });
                x += item.width + flow.spacing;
            }
            y += current.height + flow.spacing;
        }
        return {
            positions: positions,
            height: Math.max(0, y - flow.spacing)
        };
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
