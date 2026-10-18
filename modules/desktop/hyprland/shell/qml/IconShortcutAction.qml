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

    ShellAction {
        id: action
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: 42
        height: 38
        runtime: control.runtime
        theme: control.theme
        motion: control.motion
        iconOnly: true
        icon: control.icon
        title: control.title
        enabled: control.enabled
        active: control.active
        activeColor: control.activeColor
        onActivated: control.activated()
    }

    KeyHint {
        visible: control.shortcut.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: action.bottom
        anchors.topMargin: 3
        runtime: control.runtime
        theme: control.theme
        shortcut: control.shortcut
        compact: true
        emphasized: control.active
        available: control.enabled
    }
}
