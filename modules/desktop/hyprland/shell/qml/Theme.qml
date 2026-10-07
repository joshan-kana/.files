import QtQuick

QtObject {
    required property QtObject runtime

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

    readonly property real textScale: runtime.textScale

    function fontSize(size: real): int {
        return Math.max(1, Math.round(size * textScale));
    }

    readonly property int radiusSmall: 10
    readonly property int radiusMedium: 18
    readonly property int radiusLarge: 30
    readonly property int radiusPanel: 38
    readonly property real squircleExponent: runtime.squircleExponent

    readonly property real borderThin: 1
    readonly property real borderFocus: 1.5
    readonly property color panelFill: Qt.rgba(surface.r, surface.g, surface.b, runtime.panelOpacity)
    readonly property color panelBorder: Qt.rgba(accent.r, accent.g, accent.b, 0.42)
    readonly property color focusFill: Qt.rgba(surfaceRaised.r, surfaceRaised.g, surfaceRaised.b, runtime.focusOpacity)
    readonly property color scrim: Qt.rgba(background.r, background.g, background.b, runtime.scrimOpacity)
    readonly property color contextualScrim: Qt.rgba(background.r, background.g, background.b, Math.min(0.18, runtime.scrimOpacity))
    readonly property color scrimStrong: Qt.rgba(background.r, background.g, background.b, Math.min(1, runtime.scrimOpacity + 0.06))
    readonly property color scrimHeavy: Qt.rgba(background.r, background.g, background.b, Math.min(1, runtime.scrimOpacity + 0.12))
    readonly property color subtleBorder: Qt.rgba(textStrong.r, textStrong.g, textStrong.b, 0.14)
    readonly property color layer0: background
    readonly property color layer1: surface
    readonly property color layer2: surfaceRaised
    readonly property color layer3: Qt.rgba(textStrong.r, textStrong.g, textStrong.b, 0.08)
    readonly property color selectionFill: Qt.rgba(accent.r, accent.g, accent.b, 0.18)
    readonly property real panelClosedScale: 0.965

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
