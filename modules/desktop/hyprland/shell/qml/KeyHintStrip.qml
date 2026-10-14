pragma ComponentBehavior: Bound
import QtQuick

// Width-aware keyboard legend. Each shortcut uses the shared KeyHint token
// geometry, and narrow panels wrap complete key/label groups together.
Item {
    id: strip
    required property RuntimeConfig runtime
    required property Theme theme
    property var hints: []
    property bool compact: true
    property int groupSpacing: theme.spacing2
    property int rowSpacing: theme.spacing2

    implicitHeight: hintFlow.height

    Flow {
        id: hintFlow
        width: parent.width
        height: childrenRect.height
        spacing: strip.groupSpacing

        Repeater {
            model: strip.hints
            delegate: KeyHint {
                required property var modelData
                visible: modelData.visible === undefined || modelData.visible
                shortcut: modelData.shortcut
                label: modelData.label
                compact: strip.compact
                emphasized: modelData.emphasized === true
                runtime: strip.runtime
                theme: strip.theme
            }
        }
    }
}
