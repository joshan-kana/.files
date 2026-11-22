pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../modules/desktop/hyprland/shell/qml" as Desktop

TestCase {
    id: testCase
    name: "BalancedTileFlow"
    when: windowShown
    width: 1200
    height: 1200

    Desktop.BalancedTileFlow {
        id: tiles
        width: testCase.panelWidth
        spacing: 8
        textScale: testCase.fontScale
    }

    property real panelWidth: 1120
    property real fontScale: 1

    Component {
        id: tileComponent
        Rectangle {
            width: tiles.cellWidth(this)
            height: 72
        }
    }

    function checkLayout(count: int, panel: real, scale: real): void {
        panelWidth = panel;
        fontScale = scale;
        const added = [];
        for (let index = 0; index < count; index++)
            added.push(tileComponent.createObject(tiles));
        wait(5);
        const columns = tiles.columns;
        const rows = tiles.rows;
        const widerRows = count % rows;
        const wideCells = widerRows === 0 ? count : widerRows * columns;
        let expectedY = 0;
        let first = 0;

        for (let row = 0; row < rows; row++) {
            const size = widerRows === 0 || row < widerRows ? columns : columns - 1;
            const cell = Math.floor((panel - (size - 1) * tiles.spacing) / size);
            for (let column = 0; column < size; column++) {
                const tile = added[first + column];
                verify(tile !== null);
                tryCompare(tile, "width", cell);
                fuzzyCompare(tile.x, column * (cell + tiles.spacing), 0.01);
                fuzzyCompare(tile.y, expectedY, 0.01);
            }
            const last = added[first + size - 1];
            verify(panel - (last.x + last.width) < size + 0.01);
            first += size;
            expectedY += 72 + tiles.spacing;
        }
        compare(first, count);
        verify(tiles.height >= expectedY - tiles.spacing && tiles.height <= expectedY, "Flow height must contain every tile without extra rows");

        for (const tile of added)
            tile.destroy();
        wait(5);
        compare(tiles.children.length, 0);
    }

    function test_dynamicRows(): void {
        for (const count of [1, 2, 6, 8, 9, 10, 14, 15, 16]) {
            for (const panel of [420, 560, 860, 1120]) {
                for (const scale of [1, 1.5, 2])
                    checkLayout(count, panel, scale);
            }
        }
    }
}
