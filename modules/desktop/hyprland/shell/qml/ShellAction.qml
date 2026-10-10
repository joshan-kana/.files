import QtQuick

Item {
    id: root

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property string shortcut: ""
    property bool active: false
    property color activeColor: theme.accent
    property bool compact: false
    property bool iconOnly: false
    property int horizontalPadding: compact ? theme.spacing3 : theme.spacing4

    signal activated

    implicitWidth: iconOnly ? 44 : Math.max(96, content.implicitWidth + horizontalPadding * 2)
    implicitHeight: iconOnly ? 40 : compact ? 40 : 58
    Accessible.role: Accessible.Button
    Accessible.name: title
    opacity: enabled ? 1 : 0.42

    ShellSurface {
        anchors.fill: parent
        theme: root.theme
        motion: root.motion
        surfaceLayer: ShellSurface.Control
        selected: root.active
        fillColor: root.active ? Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.18) : root.theme.layer3
        cornerRadius: root.compact ? theme.radiusSmall : theme.radiusMedium
    }

    Column {
        id: content
        width: Math.max(1, root.width - (root.iconOnly ? 0 : root.horizontalPadding * 2))
        anchors.centerIn: parent
        spacing: root.theme.spacing1

        Text {
            visible: !root.iconOnly && root.icon.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            color: root.active ? root.activeColor : root.theme.textStrong
            font.family: "Symbols Nerd Font"
            font.pixelSize: root.theme.fontSize(root.compact ? 15 : 19)
        }

        ShellText {
            visible: !root.iconOnly
            width: Math.max(1, root.width - root.horizontalPadding * 2)
            horizontalAlignment: root.icon.length > 0 ? Text.AlignHCenter : Text.AlignLeft
            elide: Text.ElideRight
            runtime: root.runtime
            theme: root.theme
            text: root.title
            color: root.active ? root.activeColor : theme.textStrong
            font.pixelSize: theme.fontSize(root.compact ? 10 : 11)
            font.weight: Font.DemiBold
        }

        ShellText {
            visible: !root.iconOnly && root.subtitle.length > 0
            width: Math.max(1, root.width - root.horizontalPadding * 2)
            horizontalAlignment: root.icon.length > 0 ? Text.AlignHCenter : Text.AlignLeft
            runtime: root.runtime
            theme: root.theme
            text: root.subtitle
            color: theme.textMuted
            font.pixelSize: theme.fontSize(root.compact ? 9 : 11)
            elide: Text.ElideRight
        }
    }

    // Icon-only actions share one fixed glyph box, independent of font bearings.
    Text {
        visible: root.iconOnly
        anchors.centerIn: parent
        width: root.width
        height: root.height
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.icon
        color: root.active ? root.activeColor : root.theme.textStrong
        font.family: "Symbols Nerd Font"
        font.pixelSize: root.theme.fontSize(17)
    }

    Text {
        visible: !root.iconOnly && root.shortcut.length > 0
        anchors {
            top: parent.top
            right: parent.right
            margins: root.theme.spacing2
        }
        text: root.shortcut
        color: root.theme.textMuted
        font.family: root.runtime.fontMono
        font.pixelSize: root.theme.fontKeyHint
    }

    StateLayer {
        theme: root.theme
        motion: root.motion
        disabled: !root.enabled
        selected: root.active
        stateColor: root.active ? root.activeColor : root.theme.textStrong
        cornerRadius: root.compact ? theme.radiusSmall : theme.radiusMedium
        onActivated: root.activated()
    }
}
