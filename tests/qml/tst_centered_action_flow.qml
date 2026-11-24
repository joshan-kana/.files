pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../modules/desktop/hyprland/shell/qml" as Desktop

TestCase {
    name: "CenteredActionFlow"
    when: windowShown
    width: 800
    height: 400

    Desktop.CenteredActionFlow {
        id: flow
        width: 500
        spacing: 10
        Rectangle {
            id: first
            width: 120
            height: 40
        }
        Rectangle {
            id: second
            width: 180
            height: 50
        }
        Rectangle {
            id: third
            width: 90
            height: 30
        }
    }

    function test_wrapping(): void {
        tryCompare(first, "x", 45);
        tryCompare(second, "x", 175);
        tryCompare(third, "x", 365);
        compare(first.y, 5);
        compare(flow.height, 50);
        flow.width = 340;
        tryCompare(first, "x", 15);
        tryCompare(second, "x", 145);
        tryCompare(third, "x", 125);
        compare(third.y, 60);
        compare(flow.height, 90);
        second.visible = false;
        tryCompare(first, "x", 60);
        tryCompare(third, "x", 190);
        compare(flow.height, 40);
        second.visible = true;
        flow.width = 500;
    }
}
