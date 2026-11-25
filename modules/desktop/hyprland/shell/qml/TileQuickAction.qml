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

    // Paint the secondary hit region inside the same transformed tile body
    // as its keycap. The MouseArea below stays in the fixed hit geometry.
    Item {
        id: localFeedback
        parent: action.hint.parent
        x: action.hint.x - action.theme.spacing1
        y: action.hint.y - action.theme.spacing1
        width: action.hint.width + action.theme.spacing1 * 2
        height: action.hint.height + action.theme.spacing1 * 2
        z: 2
        visible: action.visible && action.available
    }

    StateLayer {
        id: interaction
        feedbackParent: localFeedback
        stateColor: action.theme.textStrong
        hoverOpacity: 0.09
        pressOpacity: 0.17
        theme: action.theme
        motion: action.motion
        cornerRadius: action.theme.radiusSmall
        selected: action.selected
        disabled: !action.available
        Accessible.role: Accessible.Button
        Accessible.name: action.available ? action.actionName : action.actionName + " unavailable"
        Accessible.onPressAction: action.trigger()
        onActivated: if (action.available)
            action.activated()
    }
}
