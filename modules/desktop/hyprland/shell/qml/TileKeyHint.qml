pragma ComponentBehavior: Bound
import QtQuick

// Consistent top-right shortcut placement for tile surfaces. Morphing tiles
// move their hint into the circular safe area with the same motion as the edge.
KeyHint {
    id: hint
    required property Motion motion
    property bool circular: false
    property real cornerInset: theme.spacing2
    readonly property real circleInset: {
        const radius = Math.min(parent.width, parent.height) / 2;
        return Math.max(cornerInset, radius * (1 - Math.SQRT1_2) + theme.borderFocus + theme.spacing1);
    }
    property real animatedInset: circular ? circleInset : cornerInset

    anchors {
        top: parent.top
        right: parent.right
        topMargin: animatedInset
        rightMargin: animatedInset
    }

    Behavior on animatedInset {
        Anim {
            motion: hint.motion
            type: Anim.FastSpatial
        }
    }
}
