pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root

    required property SpectrumState spectrum
    required property Theme theme
    required property SpectrumScale frequencyScale

    property int barCount: 48
    readonly property var values: spectrum.displayBands || []
    readonly property int count: Math.min(barCount, values.length)

    function levelFor(index: int): real {
        if (count === 0)
            return 0;

        // Assign disjoint bins to compact bars rather than spreading a peak
        // across overlapping neighbouring ranges.
        const first = Math.floor(index * values.length / count);
        const last = Math.max(first + 1, Math.floor((index + 1) * values.length / count));
        let level = 0;
        for (let i = first; i < last; i++)
            level = Math.max(level, values[i] || 0);
        return Math.pow(Math.max(0, Math.min(1, level)), 0.88);
    }

    Repeater {
        model: root.count

        delegate: Rectangle {
            required property int index

            readonly property real fraction: root.count <= 1 ? 0 : index / (root.count - 1)
            readonly property real center: root.frequencyScale.fromNormalized(fraction) * root.width
            readonly property real previousCenter: index > 0 ? root.frequencyScale.fromNormalized((index - 1) / (root.count - 1)) * root.width : 0
            readonly property real nextCenter: index < root.count - 1 ? root.frequencyScale.fromNormalized((index + 1) / (root.count - 1)) * root.width : root.width
            readonly property real leftEdge: index === 0 ? 0 : (previousCenter + center) / 2
            readonly property real rightEdge: index === root.count - 1 ? root.width : (center + nextCenter) / 2
            readonly property real level: root.levelFor(index)

            width: Math.max(1, (rightEdge - leftEdge) * 0.70)
            height: Math.max(2, level * root.height)
            x: Math.max(0, Math.min(root.width - width, center - width / 2))
            y: root.height - height
            radius: Math.min(width / 2, 3)
            color: Qt.rgba(root.theme.accent.r * (1 - fraction) + root.theme.positive.r * fraction, root.theme.accent.g * (1 - fraction) + root.theme.positive.g * fraction, root.theme.accent.b * (1 - fraction) + root.theme.positive.b * fraction, 0.95)
        }
    }
}
