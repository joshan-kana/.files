pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: flow
    default property alias actions: body.data
    property real spacing: 8
    property bool fillWidth: false
    implicitHeight: layout.height
    height: implicitHeight

    readonly property var layout: {
        const rows = [];
        let row = [], widthUsed = 0, rowHeight = 0;
        const limit = Math.max(1, flow.width);
        for (const item of body.children) {
            const preferredWidth = flow.fillWidth ? Math.min(limit, item.implicitWidth) : item.width;
            if (!item.visible || preferredWidth <= 0 || item.height <= 0)
                continue;
            if (row.length && widthUsed + flow.spacing + preferredWidth > limit) {
                rows.push({
                    items: row,
                    width: widthUsed,
                    height: rowHeight
                });
                row = [];
                widthUsed = 0;
                rowHeight = 0;
            }
            widthUsed += (row.length ? flow.spacing : 0) + preferredWidth;
            rowHeight = Math.max(rowHeight, item.height);
            row.push({
                item,
                preferredWidth
            });
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
            const extra = flow.fillWidth ? Math.max(0, limit - current.width) : 0;
            let x = flow.fillWidth ? 0 : Math.max(0, (limit - current.width) / 2);
            const preferredTotal = current.width - (current.items.length - 1) * flow.spacing;
            for (const entry of current.items) {
                const item = entry.item;
                const itemWidth = entry.preferredWidth + extra * entry.preferredWidth / preferredTotal;
                positions.push({
                    item: item,
                    x: x,
                    width: itemWidth,
                    y: y + (current.height - item.height) / 2
                });
                x += itemWidth + flow.spacing;
            }
            y += current.height + flow.spacing;
        }
        return {
            positions: positions,
            height: Math.max(0, y - flow.spacing)
        };
    }

    function actionWidth(item: Item): real {
        return layout.positions.find(position => position.item === item)?.width ?? Math.min(width, item.implicitWidth);
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
