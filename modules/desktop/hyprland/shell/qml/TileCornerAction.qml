pragma ComponentBehavior: Bound
import QtQuick

// The supported second action stays inside the tile's top-right corner.
// The primary hit target is a sibling below this one, never an overlay.
Item {
    id: action
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property string shortcut
    property string actionName: "Open details"
    property bool selected: false
    property color emphasisColor: theme.accent
    signal activated

    visible: shortcut.length > 0
    enabled: visible
    width: Math.max(36, hint.implicitWidth + theme.spacing1 * 2)
    height: Math.max(36, hint.implicitHeight + theme.spacing1 * 2)
    anchors {
        top: parent.top
        right: parent.right
        // Centre the visible keycap on the same inset as TileKeyHint.
        // The surrounding target remains at least 36 logical pixels.
        topMargin: Math.max(0, theme.spacing2 - (height - hint.implicitHeight) / 2)
        rightMargin: Math.max(0, theme.spacing2 - (width - hint.implicitWidth) / 2)
    }

    StateLayer {
        theme: action.theme
        motion: action.motion
        cornerRadius: action.theme.radiusSmall
        selected: action.selected
        Accessible.role: Accessible.Button
        Accessible.name: action.actionName
        Accessible.onPressAction: action.activated()
        onActivated: action.activated()
    }

    KeyHint {
        id: hint
        anchors.centerIn: parent
        shortcut: action.shortcut
        compact: true
        runtime: action.runtime
        theme: action.theme
        emphasized: action.selected
        emphasisColor: action.emphasisColor
    }
}
