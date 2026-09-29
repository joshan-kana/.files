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

    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 14
    readonly property int radiusLarge: 22

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
