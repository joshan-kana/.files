import QtQuick

ShellSurface {
    id: nav

    required property string icon

    signal activated

    implicitWidth: 34
    implicitHeight: 34
    surfaceLayer: ShellSurface.Control
    cornerRadius: motion.enabled && press.visualPressed ? theme.radiusSmall : theme.radiusMedium
    Behavior on cornerRadius {
        enabled: nav.motion.enabled
        Anim {
            motion: nav.motion
            type: Anim.FastSpatial
        }
    }
    fillColor: theme.expressiveSurfaceStrong

    Text {
        anchors.centerIn: parent
        text: nav.icon
        color: nav.theme.textStrong
        font.family: "Symbols Nerd Font"
        font.pixelSize: nav.theme.fontSize(18)
    }

    StateLayer {
        id: press
        theme: nav.theme
        motion: nav.motion
        cornerRadius: nav.cornerRadius
        onActivated: nav.activated()
    }
}
