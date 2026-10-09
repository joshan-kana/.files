import QtQuick

ShellSurface {
    id: nav

    required property string icon

    signal activated

    implicitWidth: 34
    implicitHeight: 34
    surfaceLayer: ShellSurface.Control
    cornerRadius: theme.radiusMedium
    fillColor: theme.layer3

    Text {
        anchors.centerIn: parent
        text: nav.icon
        color: nav.theme.textStrong
        font.family: "Symbols Nerd Font"
        font.pixelSize: nav.theme.fontSize(18)
    }

    StateLayer {
        theme: nav.theme
        motion: nav.motion
        cornerRadius: nav.theme.radiusMedium
        onActivated: nav.activated()
    }
}
