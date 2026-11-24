pragma ComponentBehavior: Bound
import QtQuick

CenteredActionFlow {
    id: bar
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property var entries
    required property string accentRole
    signal actionRequested(string action)

    spacing: theme.spacing2
    Repeater {
        model: bar.entries
        delegate: ShellAction {
            required property var modelData
            width: Math.min(bar.width, implicitWidth)
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
            activeColor: bar.theme.roleColor(bar.accentRole)
            enabled: modelData.enabled !== false
            shortcut: bar.runtime.shellHint(modelData.action)
            onActivated: bar.actionRequested(modelData.action)
        }
    }
}
