import QtQuick

SquircleSurface {
    id: root

    enum Layer {
        Background,
        Pane,
        Group,
        Control
    }

    required property Theme theme
    required property Motion motion
    property int surfaceLayer: ShellSurface.Pane
    property bool selected: false
    property bool outlined: false
    property bool luminous: false
    property bool hovered: false
    property color luminousColor: theme.accent
    property real lightIntensity: 1

    exponent: theme.squircleExponent
    lightColor: luminousColor
    lightStrength: luminous ? (hovered ? 0.25 : 0.145) * lightIntensity : 0

    Behavior on lightStrength {
        NumberAnimation {
            duration: root.motion.effectsFast
            easing.type: root.motion.effectsType
            easing.bezierCurve: root.motion.effectsCurve
        }
    }
    cornerRadius: theme.radiusMedium
    fillColor: {
        if (selected)
            return theme.selectionFill;

        switch (surfaceLayer) {
        case ShellSurface.Background:
            return theme.layer0;
        case ShellSurface.Group:
            return theme.expressiveSurface;
        case ShellSurface.Control:
            return theme.expressiveSurfaceStrong;
        default:
            return theme.layer1;
        }
    }
    borderColor: luminous ? Qt.rgba(theme.textStrong.r, theme.textStrong.g, theme.textStrong.b, hovered ? 0.16 : 0.075) : (outlined ? theme.subtleBorder : "transparent")
    borderWidth: luminous || outlined ? theme.borderThin : 0

    Behavior on fillColor {
        ColorAnimation {
            duration: root.motion.effectsFast
            easing.type: root.motion.effectsType
            easing.bezierCurve: root.motion.effectsCurve
        }
    }
}
