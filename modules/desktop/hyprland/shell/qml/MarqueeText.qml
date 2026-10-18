pragma ComponentBehavior: Bound
import QtQuick

// Readability behaviour, not decorative motion: overflowing labels always
// reveal their full contents, even when optional shell animations are off.
// Only overflowing, visible labels animate; fitting labels do no work.
Item {
    id: marquee

    property alias text: label.text
    property alias color: label.color
    property alias font: label.font
    property alias textFormat: label.textFormat
    property real scrollSpeed: 56 // logical pixels per second
    property int initialPause: 1250
    property int endPause: 1450
    property bool alignRight: false
    property bool alignCenter: false
    property real scrollOffset: 0
    onOverflowsChanged: {
        if (!overflows)
            scrollOffset = 0;
    }
    readonly property real overflowWidth: Math.max(0, label.implicitWidth - width)
    readonly property bool overflows: overflowWidth > 1

    clip: true
    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    height: implicitHeight

    Text {
        id: label
        x: (marquee.overflows ? 0 : marquee.alignRight ? Math.max(0, marquee.width - implicitWidth) : marquee.alignCenter ? Math.max(0, (marquee.width - implicitWidth) / 2) : 0) + marquee.scrollOffset
        anchors.verticalCenter: parent.verticalCenter
        width: implicitWidth
        textFormat: Text.PlainText
        verticalAlignment: Text.AlignVCenter
    }

    SequentialAnimation {
        id: reveal
        running: marquee.visible && marquee.width > 0 && marquee.overflows
        loops: Animation.Infinite

        PauseAnimation {
            duration: marquee.initialPause
        }
        NumberAnimation {
            target: marquee
            property: "scrollOffset"
            from: 0
            to: -marquee.overflowWidth
            duration: Math.max(700, Math.round(marquee.overflowWidth * 1000 / Math.max(1, marquee.scrollSpeed)))
            easing.type: Easing.Linear
        }
        PauseAnimation {
            duration: marquee.endPause
        }
        NumberAnimation {
            target: marquee
            property: "scrollOffset"
            to: 0
            duration: 340
            easing.type: Easing.InOutQuad
        }
    }
}
