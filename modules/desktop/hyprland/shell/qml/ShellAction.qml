import QtQuick

Item {
    id: root

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool compact: false
    property int horizontalPadding: compact ? theme.spacing3 : theme.spacing4

    signal activated

    implicitWidth: Math.max(96, content.implicitWidth + horizontalPadding * 2)
    implicitHeight: compact ? 40 : 58
    opacity: enabled ? 1 : 0.42

    ShellSurface {
        anchors.fill: parent
        theme: root.theme
        motion: root.motion
        surfaceLayer: ShellSurface.Control
        selected: root.active
        cornerRadius: root.compact ? theme.radiusSmall : theme.radiusMedium
    }

    Column {
        id: content
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }
        spacing: root.theme.spacing1

        ShellText {
            runtime: root.runtime
            theme: root.theme
            text: root.title
            color: root.active ? theme.accent : theme.textStrong
            font.pixelSize: theme.fontSize(root.compact ? 10 : 11)
            font.weight: Font.DemiBold
        }

        ShellText {
            visible: root.subtitle.length > 0
            width: Math.max(1, root.width - root.horizontalPadding * 2)
            runtime: root.runtime
            theme: root.theme
            text: root.subtitle
            color: theme.textMuted
            font.pixelSize: theme.fontSize(root.compact ? 9 : 11)
            elide: Text.ElideRight
        }
    }

    StateLayer {
        theme: root.theme
        motion: root.motion
        disabled: !root.enabled
        selected: root.active
        onActivated: root.activated()
    }
}
