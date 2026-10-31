import QtQuick

// One field treatment across launcher, clipboard, cheatsheet and galleries.
// Feature colours belong to results and actions, not focus outlines.
ShellSurface {
    id: field

    property bool fieldFocused: false

    surfaceLayer: ShellSurface.Control
    cornerRadius: theme.radiusMedium
    fillColor: theme.controlBase
    borderWidth: fieldFocused ? theme.borderFocus : theme.borderThin
    borderColor: fieldFocused ? theme.accent : theme.subtleBorder
}
