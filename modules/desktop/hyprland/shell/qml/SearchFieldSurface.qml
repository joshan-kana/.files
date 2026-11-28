import QtQuick

// One field treatment across launcher, clipboard, cheatsheet and galleries.
// Feature colours belong to results and actions, not focus outlines.
ShellSurface {
    id: field

    property bool fieldFocused: false

    surfaceLayer: ShellSurface.Control
    cornerRadius: fieldFocused ? theme.radiusSmall : theme.radiusMedium

    Behavior on cornerRadius {
        Anim {
            motion: field.motion
            type: Anim.FastSpatial
        }
    }
    fillColor: fieldFocused ? theme.expressiveSurfaceStrong : theme.controlBase
    borderWidth: fieldFocused ? theme.borderFocus : theme.borderThin
    borderColor: fieldFocused ? theme.focusColor : theme.subtleBorder
}
