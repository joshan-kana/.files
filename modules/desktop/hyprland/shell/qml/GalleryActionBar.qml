pragma ComponentBehavior: Bound
import QtQuick

CenteredActionFlow {
    id: bar
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property var entries
    signal actionRequested(string action)

    function triggerAction(action: string): void {
        const index = entries.findIndex(entry => entry.action === action);
        if (index >= 0)
            (buttons.itemAt(index) as ShellAction)?.trigger();
    }

    spacing: theme.spacing2
    fillWidth: true
    Repeater {
        id: buttons
        model: bar.entries.length
        delegate: ShellAction {
            id: button
            required property int index
            readonly property var modelData: bar.entries[index]
            width: bar.actionWidth(button)
            height: Math.max(bar.theme.minActionTarget, implicitHeight)
            runtime: bar.runtime
            theme: bar.theme
            motion: bar.motion
            compact: true
            horizontalCompact: true
            title: modelData.title
            icon: modelData.glyph || ""
            iconOnly: !!modelData.iconOnly
            inlineIconHint: iconOnly
            active: !!modelData.active
            activeColor: active ? bar.theme.toggleColor : bar.theme.commandColor
            enabled: modelData.enabled !== false
            shortcut: bar.runtime.shellHint(modelData.action)
            onActivated: bar.actionRequested(modelData.action)
        }
    }
}
