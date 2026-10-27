import QtQuick

QtObject {
    required property RuntimeConfig runtime

    readonly property color background: runtime.background
    readonly property color surface: runtime.surface
    readonly property color surfaceRaised: runtime.surfaceRaised
    readonly property color outline: runtime.outline
    readonly property color textMuted: runtime.textMuted
    readonly property color text: runtime.text
    readonly property color textStrong: runtime.textStrong
    readonly property color critical: runtime.critical
    readonly property color warning: runtime.warning
    readonly property color positive: runtime.positive
    readonly property color accent: runtime.accent
    readonly property color accentSecondary: runtime.accentSecondary
    readonly property color accentTertiary: runtime.accentTertiary
    readonly property color accentWarm: runtime.accentWarm
    readonly property color accentWorkspace: runtime.accentWorkspace
    readonly property color accentUtility: runtime.accentUtility
    readonly property color accentEnergy: runtime.accentEnergy
    readonly property color accentNature: runtime.accentNature

    // Stylix owns the palette. Components select a semantic role, not a
    // favourite colour; surface fills remain quiet regardless of the role.
    function roleColor(role: string): color {
        switch (role) {
        case "media":
            return accentSecondary;
        case "workspace":
            return accentWorkspace;
        case "attention":
            return critical;
        case "display":
            return accent;
        case "connectivity":
            return accentTertiary;
        case "warmth":
            return accentWarm;
        case "capture":
            return accentWarm;
        case "audio":
            return accentUtility;
        case "resources":
            return accentEnergy;
        case "power":
            return accent;
        case "notifications":
        case "calendar":
        case "wallpaper":
            return accentNature;
        case "clipboard":
            return accentUtility;
        case "weather":
            return accentWarm;
        case "positive":
            return positive;
        case "warning":
            return warning;
        case "critical":
            return critical;
        default:
            return accent;
        }
    }

    function audioLevelColor(muted: bool): color {
        return muted ? warning : roleColor("audio");
    }

    function powerProfileColor(profile: string): color {
        return profile === "power-saver" ? warning : roleColor("power");
    }

    // Shared spectrum colour ramp, expressed only in Stylix Base16 tokens.
    // Bass is warm, mids move through green, and treble ends in violet.
    function spectrumColor(position: real): color {
        const stops = [accentWarm, accentEnergy, accentNature, accentTertiary, accentSecondary];
        const scaled = Math.max(0, Math.min(1, position)) * (stops.length - 1);
        const index = Math.min(stops.length - 2, Math.floor(scaled));
        return blend(stops[index], stops[index + 1], scaled - index);
    }

    // Single event-driven signal for every shell surface that opts into the
    // music-reactive treatment. Theme remains the only visual style owner.
    property bool musicReactiveEnabled: false
    property bool shellGlassEnabled: false
    readonly property real glassOpacity: 0.70
    property real musicReactiveEnergy: 0
    property real musicReactiveBeat: 0
    property real musicReactiveTreble: 0

    readonly property real textScale: runtime.textScale

    function fontSize(size: real): int {
        return Math.max(1, Math.round(size * textScale));
    }

    readonly property int radiusSmall: 14
    readonly property int radiusMedium: 25
    readonly property int radiusIsland: 22
    readonly property int radiusLarge: 42
    readonly property int radiusPanel: 62
    readonly property int barHeight: 70
    readonly property int barInsetTop: 12
    readonly property int barInsetBottom: 8
    readonly property real squircleExponent: runtime.squircleExponent

    // Use the palette's own luminance rather than a separate dark/light flag:
    // wallpapers and full-system themes retain their actual tonal identity.
    function luminance(color: color): real {
        function channel(value: real): real {
            return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
        }
        return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
    }

    // Small labels must remain readable on light and dark palettes.
    // Return an existing Stylix token, never an interpolated accent colour.
    function readableRoleColor(role: string): color {
        const chosen = roleColor(role);
        const light = Math.max(luminance(chosen), luminance(panelBase));
        const dark = Math.min(luminance(chosen), luminance(panelBase));
        return (light + 0.05) / (dark + 0.05) >= 4.5 ? chosen : textStrong;
    }

    function blend(base: color, overlay: color, amount: real): color {
        const mix = Math.max(0, Math.min(1, amount));
        return Qt.rgba(base.r + (overlay.r - base.r) * mix, base.g + (overlay.g - base.g) * mix, base.b + (overlay.b - base.b) * mix, 1);
    }

    readonly property bool dark: luminance(background) < luminance(textStrong)
    // Four independently elevated steps, all derived from the official
    // Stylix palette. A dark base never becomes frosted grey from wallpaper.
    readonly property color panelBase: blend(background, surface, dark ? 0.33 : 0.22)
    readonly property color paneBase: blend(background, surface, dark ? 0.68 : 0.55)
    readonly property color groupBase: blend(paneBase, surfaceRaised, dark ? 0.25 : 0.17)
    readonly property color controlBase: blend(paneBase, surfaceRaised, dark ? 0.35 : 0.24)

    readonly property real borderThin: 1
    readonly property real borderFocus: 2
    readonly property color panelFill: panelBase
    readonly property color panelBorder: Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.26 : 0.31)
    readonly property color focusFill: Qt.rgba(surfaceRaised.r, surfaceRaised.g, surfaceRaised.b, runtime.focusOpacity)
    readonly property color scrim: Qt.rgba(background.r, background.g, background.b, runtime.scrimOpacity)
    readonly property color contextualScrim: Qt.rgba(background.r, background.g, background.b, Math.min(0.18, runtime.scrimOpacity))
    readonly property color scrimStrong: Qt.rgba(background.r, background.g, background.b, Math.min(1, runtime.scrimOpacity + 0.06))
    readonly property color scrimHeavy: Qt.rgba(background.r, background.g, background.b, Math.min(1, runtime.scrimOpacity + 0.12))
    readonly property color subtleBorder: Qt.rgba(textStrong.r, textStrong.g, textStrong.b, dark ? 0.12 : 0.17)
    readonly property color layer0: background
    readonly property color layer1: paneBase
    readonly property color layer2: groupBase
    readonly property color layer3: blend(paneBase, accent, dark ? 0.08 : 0.07)
    readonly property color selectionFill: Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.20 : 0.15)
    readonly property color selectedTabFill: blend(controlBase, accent, dark ? 0.52 : 0.34)
    readonly property color expressiveSurface: blend(groupBase, accent, dark ? 0.035 : 0.022)
    readonly property color expressiveSurfaceStrong: blend(controlBase, accent, dark ? 0.055 : 0.035)
    readonly property real panelClosedScale: 0.965

    readonly property int fontKeyHint: fontSize(11)
    readonly property int keycapHeight: Math.max(25, fontSize(20))
    readonly property int keycapInset: 7
    readonly property int keyHintGap: 8
    readonly property int keyHintGroupGap: 28
    readonly property int minActionTarget: 44
    readonly property int fontPanelEyebrow: fontSize(11)
    readonly property int fontPanelTitle: fontSize(27)
    readonly property int fontSubpanelEyebrow: fontSize(10)
    readonly property int fontSubpanelTitle: fontSize(24)

    readonly property int panelTopOffset: 82
    readonly property int panelSideOffset: 24

    readonly property int spacing1: 4
    readonly property int spacing2: 8
    readonly property int spacing3: 12
    readonly property int spacing4: 16
    readonly property int spacing5: 24
    readonly property int spacing6: 32
}
