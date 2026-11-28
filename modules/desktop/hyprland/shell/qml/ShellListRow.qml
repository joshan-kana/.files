pragma ComponentBehavior: Bound
import QtQuick

// The list owns its item geometry and keyboard selection. Only the painted
// contour changes, keeping the full row hit target and list position stable.
ShellSurface {
    id: root

    property bool pressedFeedback: false
    property color selectionColor: theme.focusColor

    surfaceLayer: ShellSurface.Control
    cornerRadius: motion.enabled && pressedFeedback ? theme.radiusSmall : selected ? theme.radiusLarge : theme.radiusMedium
    borderColor: selected ? selectionColor : "transparent"
    borderWidth: selected ? theme.borderFocus : 0

    Behavior on cornerRadius {
        enabled: root.motion.enabled
        Anim {
            motion: root.motion
            type: Anim.FastSpatial
        }
    }
}
