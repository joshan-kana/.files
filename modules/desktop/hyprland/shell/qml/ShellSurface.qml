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
    // Compact bar islands share the same music treatment as larger panes.
    // Their connected outline is painted by DesktopFrame, not by each island.
    property bool reactiveSurface: false
    property bool frameConnected: false

    // Change fill alpha, not the Item opacity: children, icons and text stay
    // fully legible while the compositor blurs only the shaped backdrop.
    // The connected frame owns the glass/tint for attached surfaces. A
    // second translucent fill here would darken it and blur the same backdrop
    // twice. Detached surfaces continue to paint and blur themselves.
    fillOpacity: frameConnected ? 0 : !glassAllowed || !theme.shellGlassEnabled || surfaceLayer === ShellSurface.Background ? 1 : surfaceLayer === ShellSurface.Pane ? theme.glassOpacity : surfaceLayer === ShellSurface.Group ? Math.min(1, theme.glassOpacity * (0.58 / 0.70)) : Math.min(1, theme.glassOpacity * (0.74 / 0.70))

    Behavior on fillOpacity {
        Anim {
            motion: root.motion
            type: Anim.FastEffects
        }
    }

    // Every reactive pane and detached island consumes the spectrum's
    // three-stop ramp. Connected islands stay transparent: DesktopFrame
    // owns their shared screen-wide gradient and silhouette.
    readonly property bool musicActive: theme.musicReactiveEnabled && (reactiveSurface || (surfaceLayer === ShellSurface.Pane && (elevated || width >= 300)) || (surfaceLayer === ShellSurface.Group && width >= 480))

    reactiveGradientStrength: musicActive ? theme.musicReactiveWash : 0
    reactiveGradientLow: theme.spectrumColor(0)
    reactiveGradientMid: theme.spectrumColor(0.5)
    reactiveGradientHigh: theme.spectrumColor(1)
    reactiveGradientPhase: musicActive && motion.enabled ? theme.musicReactiveFlow : 0
    reactiveGradientMovement: musicActive && motion.enabled ? theme.musicReactiveMovement : 0
    reactiveGradientKick: musicActive && motion.enabled ? theme.musicReactiveKick : 0

    shadowStrength: elevated ? (theme.dark ? 0.25 : 0.16) : 0
    shadowOffset: elevated ? 3 : 0

    exponent: theme.squircleExponent
    // Radial gradients on narrow islands looked like independent discs.
    // Audio changes the actual fill rather than adding isolated spotlights.
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
        let base;
        if (selected)
            base = theme.selectionFill;
        else
            switch (surfaceLayer) {
            case ShellSurface.Background:
                base = theme.layer0;
                break;
            case ShellSurface.Group:
                base = theme.expressiveSurface;
                break;
            case ShellSurface.Control:
                base = theme.expressiveSurfaceStrong;
                break;
            default:
                base = theme.layer1;
                break;
            }
        return base;
    }
    borderColor: frameConnected ? "transparent" : luminous ? Qt.rgba(theme.textStrong.r, theme.textStrong.g, theme.textStrong.b, hovered ? 0.16 : 0.075) : (outlined ? theme.subtleBorder : "transparent")
    // Audio only modulates the fill and soft light. Borders keep their
    // ordinary colour and width, including surfaces with no outline.
    borderWidth: frameConnected ? 0 : luminous || outlined ? theme.borderThin : 0

    Behavior on fillColor {
        enabled: !root.musicActive
        ColorAnimation {
            duration: root.motion.effectsFast
            easing.type: root.motion.effectsType
            easing.bezierCurve: root.motion.effectsCurve
        }
    }
}
