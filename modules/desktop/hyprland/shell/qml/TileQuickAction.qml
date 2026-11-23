pragma ComponentBehavior: Bound
import QtQuick

// Independent quick action on the top-left of a tile with details.
// The remainder of the tile opens details without modifying backend state.
Item {
    id: action
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property string shortcut
    property string actionName: "Toggle"
    property bool selected: false
    property bool available: true
    property color emphasisColor: theme.accent
    signal activated

    visible: shortcut.length > 0
    width: Math.max(36, hint.implicitWidth + theme.spacing1 * 2)
    height: Math.max(36, hint.implicitHeight + theme.spacing1 * 2)
    anchors {
        top: parent.top
        left: parent.left
        topMargin: Math.max(0, theme.spacing2 - (height - hint.implicitHeight) / 2)
        leftMargin: Math.max(0, theme.spacing2 - (width - hint.implicitWidth) / 2)
    }

    StateLayer {
        theme: action.theme
        motion: action.motion
        cornerRadius: action.theme.radiusSmall
        selected: action.selected
        disabled: !action.available
        Accessible.role: Accessible.Button
        Accessible.name: action.available ? action.actionName : action.actionName + " unavailable"
        Accessible.onPressAction: if (action.available)
            action.activated()
        onActivated: if (action.available)
            action.activated()
    }

    KeyHint {
        id: hint
        anchors.centerIn: parent
        shortcut: action.shortcut
        compact: true
        runtime: action.runtime
        theme: action.theme
        available: action.available
        emphasized: action.selected
        emphasisColor: action.emphasisColor
    }
}
