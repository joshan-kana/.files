pragma ComponentBehavior: Bound
import QtQuick

// Primary hints belong to the top-left corner; distinct details to the
// top-right. Both follow the same shape-relative squircle/circle insets.
KeyHint {
    id: hint
    required property Motion motion
    property bool circular: false
    property bool primary: false
    property real cornerInset: theme.spacing2
    readonly property real circleInset: {
        const radius = Math.min(parent.width, parent.height) / 2;
        return Math.max(cornerInset, radius * (1 - Math.SQRT1_2) + theme.borderFocus + theme.spacing1);
    }
    property real animatedInset: circular ? circleInset : cornerInset

    anchors {
        top: parent.top
        left: primary ? parent.left : undefined
        right: primary ? undefined : parent.right
        topMargin: animatedInset
        leftMargin: primary ? animatedInset : 0
        rightMargin: primary ? 0 : animatedInset
    }

    Behavior on animatedInset {
        Anim {
            motion: hint.motion
            type: Anim.FastSpatial
        }
    }
}
