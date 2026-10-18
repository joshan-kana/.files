pragma ComponentBehavior: Bound
import QtQuick

// Shared button and distinct keycap: neither glyph nor hint occupies the
// other's space. Used for the keyboard-first audio output/input rows.
Item {
    id: control

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property string icon: ""
    property string title: ""
    property string shortcut: ""
    property bool active: false
    property color activeColor: theme.accent

    signal activated

    implicitWidth: 44
    implicitHeight: 66
    Accessible.role: Accessible.Button
    Accessible.name: title + (shortcut.length > 0 ? ", " + shortcut : "")

    // The action and its keycap share one real surface, including hover,
    // focus, outline, disabled state and changing corner geometry.
    ShellAction {
        anchors.fill: parent
        runtime: control.runtime
        theme: control.theme
        motion: control.motion
        iconOnly: true
        iconHint: control.shortcut.length > 0
        shortcut: control.shortcut
        icon: control.icon
        title: control.title
        enabled: control.enabled
        active: control.active
        activeColor: control.activeColor
        onActivated: control.activated()
    }
}
