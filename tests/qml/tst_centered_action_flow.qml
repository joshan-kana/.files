pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../modules/desktop/hyprland/shell/qml" as Desktop

Item {
    width: 800
    height: 400

    Desktop.CenteredActionFlow {
        id: flow
        width: 500
        spacing: 10
        Rectangle {
            id: first
            implicitWidth: 120
            width: implicitWidth
            height: 40
        }
        Rectangle {
            id: second
            implicitWidth: 180
            width: implicitWidth
            height: 50
        }
        Rectangle {
            id: third
            implicitWidth: 90
            width: implicitWidth
            height: 30
        }
    }

    Desktop.CenteredActionFlow {
        id: filled
        fillWidth: true
        y: 150
        width: 500
        spacing: 10
        Rectangle {
            id: fillFirst
            implicitWidth: 120
            width: filled.actionWidth(fillFirst)
            height: 40
        }
        Rectangle {
            id: fillSecond
            implicitWidth: 180
            width: filled.actionWidth(fillSecond)
            height: 50
        }
        Rectangle {
            id: fillThird
            implicitWidth: 90
            width: filled.actionWidth(fillThird)
            height: width >= 100 ? 30 : 60
        }
    }

    TestCase {
        name: "CenteredActionFlow"
        when: windowShown

        function test_fillWidth(): void {
            tryCompare(fillFirst, "x", 0);
            tryVerify(() => Math.abs(fillThird.x + fillThird.width - filled.width) < 0.01);
            verify(fillFirst.width > fillFirst.implicitWidth);
            filled.width = 340;
            tryVerify(() => Math.abs(fillSecond.x + fillSecond.width - filled.width) < 0.01);
            tryCompare(fillThird, "x", 0);
            tryCompare(fillThird, "width", 340);
            tryCompare(fillThird, "height", 30);
            filled.width = 80;
            tryCompare(fillThird, "width", 80);
            tryCompare(fillThird, "height", 60);
            filled.width = 500;
            tryVerify(() => Math.abs(fillThird.x + fillThird.width - filled.width) < 0.01);
        }

        function test_wrapping(): void {
            verify(flow.visible);
            compare(flow.layout.positions.length, 3);
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
}
