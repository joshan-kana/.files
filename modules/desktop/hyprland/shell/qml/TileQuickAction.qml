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
    required property Item hint
    readonly property bool visualPressed: interaction.visualPressed
    readonly property bool pointerHovered: interaction.pointerHovered
    property string actionName: "Toggle"
    property bool selected: false
    property bool available: true
    property color emphasisColor: theme.toggleColor
    signal activated

    function trigger(): void {
        if (!available || !visible)
            return;
        interaction.trigger();
    }

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
        id: interaction
        // The hit target stays large, but the feedback is painted inside
        // the existing keycap contour rather than around its hit rectangle.
        feedbackParent: action.hint
        theme: action.theme
        motion: action.motion
        cornerRadius: Math.min(9, action.hint.height / 3)
        hoverOpacity: 0.14
        pressOpacity: 0.24
        stateColor: action.emphasisColor
        selected: action.selected
        disabled: !action.available
        Accessible.role: Accessible.Button
        Accessible.name: action.available ? action.actionName : action.actionName + " unavailable"
        Accessible.onPressAction: action.trigger()
        onActivated: if (action.available)
            action.activated()
    }
}
