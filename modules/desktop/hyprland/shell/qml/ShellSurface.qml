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
    property bool elevated: false
    property bool glassAllowed: true

    // Change fill alpha, not the Item opacity: children, icons and text stay
    // fully legible while the compositor blurs only the shaped backdrop.
    fillOpacity: !glassAllowed || !theme.shellGlassEnabled || surfaceLayer === ShellSurface.Background ? 1 : surfaceLayer === ShellSurface.Pane ? theme.glassOpacity : surfaceLayer === ShellSurface.Group ? 0.58 : 0.74

    Behavior on fillOpacity {
        Anim {
            motion: root.motion
            type: Anim.FastEffects
        }
    }

    // Shape tessellation is not free. React only on large structural
    // surfaces; updating every control and its SVG gradient at audio cadence
    // starves the QML scene graph and destroys frame pacing.
    readonly property bool musicActive: theme.musicReactiveEnabled && motion.enabled && ((surfaceLayer === ShellSurface.Pane && (elevated || width >= 300)) || (surfaceLayer === ShellSurface.Group && width >= 480))
    readonly property real musicBass: musicActive ? theme.musicReactiveEnergy : 0
    readonly property real musicBeat: musicActive ? theme.musicReactiveBeat : 0
    readonly property real musicTreble: musicActive ? theme.musicReactiveTreble : 0
    readonly property real musicGlow: musicBass * 0.55 + musicBeat * 0.38
    readonly property color musicLight: theme.blend(theme.accent, theme.positive, musicTreble * 0.85)

    shadowStrength: elevated ? (theme.dark ? 0.22 : 0.13) : 0
    shadowOffset: elevated ? 3 : 0

    exponent: theme.squircleExponent
    lightColor: musicActive ? musicLight : luminousColor
    lightStrength: Math.min(0.92, (luminous ? (hovered ? 0.25 : 0.145) * lightIntensity : 0) + musicGlow)

    Behavior on lightStrength {
        enabled: !root.musicActive
        NumberAnimation {
            duration: root.motion.effectsFast
            easing.type: root.motion.effectsType
            easing.bezierCurve: root.motion.effectsCurve
        }
    }
    cornerRadius: theme.radiusMedium
    fillColor: {
        let base;
        if (selected)
            base = theme.selectionFill;
        else
            switch (surfaceLayer) {
            case ShellSurface.Background:
                base = theme.materialCanvas;
                break;
            case ShellSurface.Group:
                base = theme.materialContainer;
                break;
            case ShellSurface.Control:
                base = theme.materialContainerHigh;
                break;
            default:
                base = theme.materialContainerLow;
                break;
            }
        // A sustained 808 colours the whole surface; transient attacks
        // brighten its rim. This stays behind content and keeps text legible.
        return musicActive ? theme.blend(base, musicLight, musicBass * 0.22 + musicBeat * 0.11) : base;
    }
    borderColor: musicActive ? Qt.rgba(musicLight.r, musicLight.g, musicLight.b, Math.min(0.72, musicBass * 0.47 + musicBeat * 0.36)) : luminous ? Qt.rgba(theme.textStrong.r, theme.textStrong.g, theme.textStrong.b, hovered ? 0.16 : 0.075) : (outlined ? theme.subtleBorder : "transparent")
    // Changing ShapePath stroke width each FFT update re-tessellates the
    // native superellipse. The geometry changes once per toggle, never on
    // music samples; its colour and luminance carry the modulation.
    borderWidth: musicActive ? theme.borderThin : luminous || outlined ? theme.borderThin : 0

    Behavior on fillColor {
        enabled: !root.musicActive
        ColorAnimation {
            duration: root.motion.effectsFast
            easing.type: root.motion.effectsType
            easing.bezierCurve: root.motion.effectsCurve
        }
    }
}
