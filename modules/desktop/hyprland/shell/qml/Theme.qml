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
    readonly property color accentTertiary: runtime.accentTertiary

    // The theme scope assigns Stylix colors to semantic roles.
    // Components select a role without embedding palette policy.
    function roleColor(role: string): color {
        const chosen = runtime.roleColors[role];
        return chosen ? chosen : accent;
    }

    function weatherColor(code: int, daylight: bool): color {
        if (code < 0 || code === 3 || code === 45 || code === 48)
            return textMuted;
        if (code >= 95)
            return roleColor("warning");
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82))
            return roleColor("precipitation");
        if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86))
            return roleColor("cold");
        return roleColor(daylight ? "daylight" : "night");
    }

    function capabilityRole(kind: string): string {
        return ({
                windows: "display",
                glass: "connectivity",
                nightLight: "warmth",
                alerts: "notifications",
                stay: "inhibition",
                power: "power",
                spectrum: "spectrum",
                reactive: "reactive",
                bar: "workspace",
                frame: "display",
                motion: "motion",
                displays: "display"
            })[kind] || "display";
    }

    function audioLevelColor(muted: bool): color {
        return muted ? warning : roleColor("audio");
    }

    function powerProfileColor(profile: string): color {
        return profile === "power-saver" ? positive : profile === "performance" ? warning : roleColor("power");
    }

    // Base16 red at the bass end blends through primary blue to cyan treble.
    // One ramp serves every shared bar, curve, and wallpaper visualiser.
    function spectrumColor(position: real): color {
        const stops = [critical, accent, accentTertiary];
        const scaled = Math.max(0, Math.min(1, position)) * (stops.length - 1);
        const index = Math.min(stops.length - 2, Math.floor(scaled));
        return blend(stops[index], stops[index + 1], scaled - index);
    }

    // Single event-driven signal for every shell surface that opts into the
    // music-reactive treatment. Theme remains the only visual style owner.
    property bool musicReactiveEnabled: false
    property bool shellGlassEnabled: false
    property real glassOpacity: runtime.appearanceDefaults.glassOpacity
    property real musicReactiveEnergy: 0
    property real musicReactiveBeat: 0
    property real musicReactiveIntensity: runtime.appearanceDefaults.musicReactiveIntensity
    // Share the spectrum's red/blue/cyan ramp with the shell, without
    // creating per-frame colour arrays or a second audio signal pipeline.
    // Music changes tint strength; the palette stays anchored to bass/treble.
    readonly property real musicReactiveWash: musicReactiveEnabled ? Math.min(0.60, 0.42 * musicReactiveIntensity, (musicReactiveEnergy * 0.58 + musicReactiveBeat * 0.14) * musicReactiveIntensity) : 0
    function reactiveColor(base: color, position: real): color {
        return musicReactiveWash > 0 ? blend(base, spectrumColor(position), musicReactiveWash) : base;
    }
    function reactiveFrameColor(position: real): color {
        const tinted = reactiveColor(background, position);
        return Qt.rgba(tinted.r, tinted.g, tinted.b, shellGlassEnabled ? glassOpacity : 1);
    }

    readonly property real textScale: runtime.textScale

    function fontSize(size: real): int {
        return Math.max(1, Math.round(size * textScale));
    }

    // Library cards keep readable names and a useful preview aspect at every
    // supported scale, rather than stretching a single column across the hub.
    function galleryColumns(width: real): int {
        return Math.max(1, Math.min(3, Math.floor((width + spacing2) / (fontSize(270) + spacing2))));
    }

    function galleryCellHeight(cellWidth: real): int {
        return Math.max(fontSize(150), Math.round((cellWidth - spacing2) / 1.9) + fontSize(30));
    }

    readonly property int radiusSmall: 14
    readonly property int radiusMedium: 25
    readonly property int radiusIsland: 22
    // Reserve the largest Controls detail viewport once. Switching gallery
    // layouts must not resize the Wayland backing layer during its morph.
    readonly property int controlsDetailWidth: 1120
    readonly property int compactDetailWidth: Math.min(controlsDetailWidth, fontSize(640))
    readonly property int standardDetailWidth: Math.min(controlsDetailWidth, fontSize(800))
    readonly property int richDetailWidth: Math.min(controlsDetailWidth, fontSize(960))
    readonly property int radiusLarge: 42
    readonly property int radiusPanel: 62
    // The visible islands are vertically centred inside the reserved bar.
    property int barIslandHeight: runtime.appearanceDefaults.barIslandHeight
    readonly property int barInsetTop: 16
    readonly property int barInsetBottom: barInsetTop
    readonly property int barHeight: barIslandHeight + barInsetTop + barInsetBottom
    property int frameThickness: runtime.appearanceDefaults.frameThickness
    // Use the same large squircle family as the rest of the shell. The
    // bigger panel radius made the monitor outline look excessively bulbous.
    readonly property int frameRounding: radiusLarge
    // End islands sit inside the frame edge, with just enough room for the
    // frame and a rounded outer shoulder. The joined contour adapts its top
    // corners to this real inset rather than clipping the island against a
    // second, full-size panel corner.
    readonly property int frameIslandInset: frameThickness + radiusIsland * 2 + spacing1
    readonly property int frameIslandGap: radiusIsland * 2 + spacing2
    readonly property int barSelectionInset: 8
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

    function onColor(backgroundColor: color): color {
        const first = (Math.max(luminance(background), luminance(backgroundColor)) + 0.05) / (Math.min(luminance(background), luminance(backgroundColor)) + 0.05);
        const second = (Math.max(luminance(textStrong), luminance(backgroundColor)) + 0.05) / (Math.min(luminance(textStrong), luminance(backgroundColor)) + 0.05);
        return first >= second ? background : textStrong;
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
    readonly property color focusFill: Qt.rgba(surfaceRaised.r, surfaceRaised.g, surfaceRaised.b, runtime.focusOpacity)
    // A light palette must not produce a light veil over authentication or
    // modal content. Use a dark Stylix role for every shared dimming level.
    readonly property color scrimBase: dark ? background : textStrong
    readonly property color scrim: Qt.rgba(scrimBase.r, scrimBase.g, scrimBase.b, runtime.scrimOpacity)
    readonly property color scrimStrong: Qt.rgba(scrimBase.r, scrimBase.g, scrimBase.b, Math.min(1, runtime.scrimOpacity + 0.06))
    readonly property color scrimHeavy: Qt.rgba(scrimBase.r, scrimBase.g, scrimBase.b, Math.min(1, runtime.scrimOpacity + 0.12))
    readonly property color subtleBorder: Qt.rgba(textStrong.r, textStrong.g, textStrong.b, dark ? 0.12 : 0.17)
    readonly property color glassContourBorder: Qt.rgba(textStrong.r, textStrong.g, textStrong.b, dark ? 0.22 : 0.25)
    readonly property color layer0: background
    readonly property color layer1: paneBase
    readonly property color layer2: groupBase
    readonly property color layer3: blend(paneBase, accent, dark ? 0.08 : 0.07)
    readonly property color selectionFill: Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.20 : 0.15)
    // Selection is a tonal container, not the full-strength command accent.
    // Both colours follow the active Base16 palette and semantic role.
    function choiceFill(role: color): color {
        return blend(controlBase, role, dark ? 0.34 : 0.22);
    }
    function choiceForeground(role: color): color {
        const fill = choiceFill(role);
        const contrast = (Math.max(luminance(role), luminance(fill)) + 0.05) / (Math.min(luminance(role), luminance(fill)) + 0.05);
        return contrast >= 4.5 ? role : onColor(fill);
    }
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
    readonly property int fontAction: fontSize(13)
    readonly property int fontCompactAction: fontSize(12)
    readonly property int fontSupporting: fontSize(12)
    readonly property int fontDetailTitle: fontSize(22)
    readonly property int fontReadback: fontSize(15)
    readonly property int fontSection: fontSize(14)
    readonly property int fontUtility: fontSize(11)
    readonly property int fontDisplay: fontSize(32)
    readonly property int iconSmall: fontSize(16)
    readonly property int iconRegular: fontSize(20)
    readonly property int iconLarge: fontSize(26)
    readonly property int compactTrack: fontSize(6)
    readonly property int standardTrack: fontSize(10)
    readonly property int prominentTrack: fontSize(14)
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
}
