import QtQuick

// Rebalance each section into full-width rows without an orphan last row.
Flow {
    height: childrenRect.height
    property real textScale: 1
    readonly property real minimumTileWidth: 140 * textScale
    readonly property int capacity: Math.max(1, Math.min(7, Math.floor((width + spacing) / (minimumTileWidth + spacing))))
    readonly property int rows: Math.max(1, Math.ceil(children.length / capacity))
    readonly property int columns: Math.max(1, Math.ceil(children.length / rows))

    function cellWidth(tile: Item): real {
        const index = children.indexOf(tile);
        if (index < 0)
            return 1;
        const widerRows = children.length % rows;
        const count = widerRows === 0 || index < widerRows * columns ? columns : columns - 1;
        return Math.max(1, Math.floor((width - spacing * (count - 1)) / count));
    }
}
