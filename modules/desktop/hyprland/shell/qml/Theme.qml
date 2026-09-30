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

    readonly property int radiusSmall: 10
    readonly property int radiusMedium: 18
    readonly property int radiusLarge: 30
    readonly property int radiusPanel: 38
    readonly property real squircleExponent: 4.5

    readonly property real borderThin: 1
    readonly property real borderFocus: 1.5
    readonly property color panelFill: Qt.rgba(surface.r, surface.g, surface.b, 0.99)
    readonly property color panelBorder: Qt.rgba(accent.r, accent.g, accent.b, 0.42)
    readonly property color focusFill: Qt.rgba(surfaceRaised.r, surfaceRaised.g, surfaceRaised.b, 0.96)
    readonly property real panelClosedScale: 0.965

    readonly property int fontPanelEyebrow: 11
    readonly property int fontPanelTitle: 27
    readonly property int fontSubpanelEyebrow: 10
    readonly property int fontSubpanelTitle: 24

    readonly property int spacing1: 4
    readonly property int spacing2: 8
    readonly property int spacing3: 12
    readonly property int spacing4: 16
    readonly property int spacing5: 24
    readonly property int spacing6: 32

    readonly property int motionFast: 120
    readonly property int motionNormal: 180
    readonly property int motionSlow: 280
}
