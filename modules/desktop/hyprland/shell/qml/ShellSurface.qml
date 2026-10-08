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

    exponent: theme.squircleExponent
    cornerRadius: theme.radiusMedium
    fillColor: {
        if (selected)
            return theme.selectionFill;

        switch (surfaceLayer) {
        case ShellSurface.Background:
            return theme.layer0;
        case ShellSurface.Group:
            return theme.layer2;
        case ShellSurface.Control:
            return theme.layer3;
        default:
            return theme.layer1;
        }
    }
    borderColor: outlined ? theme.subtleBorder : "transparent"
    borderWidth: outlined ? theme.borderThin : 0

    Behavior on fillColor {
        ColorAnimation {
            duration: root.motion.effectsFast
            easing.type: root.motion.effectsType
        }
    }
}
