pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root

    required property SpectrumState spectrum
    required property Theme theme
    required property SpectrumScale frequencyScale

    property int barCount: 48
    // Hidden, prewarmed hub pages retain their models but do no visualizer
    // calculations. Enabled is inherited from the owning inactive Loader.
    readonly property bool rendering: enabled && visible && opacity > 0 && width > 0 && height > 0 && spectrum.hasEnergy
    readonly property int count: Math.min(barCount, spectrum.bands.length)

    // Analyser bands are logarithmic. The inverse-warped sampling boundaries
    // change only when the display scale or bar count changes.
    readonly property var bandEdges: {
        const edges = [];
        for (let i = 0; i <= count; i++)
            edges.push(frequencyScale.toNormalized(i / Math.max(1, count)));
        return edges;
    }

    // One aggregation per spectrum frame instead of a separate QML function
    // call and raw-bin scan from every bar delegate.
    readonly property var levels: {
        if (!rendering)
            return [];
        const values = spectrum.bands;
        const levels = [];
        for (let i = 0; i < count; i++) {
            const first = Math.max(0, Math.floor(bandEdges[i] * (values.length - 1)));
            const last = Math.min(values.length - 1, Math.ceil(bandEdges[i + 1] * (values.length - 1)));
            let peak = 0;
            for (let sample = first; sample <= last; sample++)
                peak = Math.max(peak, values[sample] || 0);
            levels.push(Math.pow(Math.max(0, Math.min(1, peak)), 0.88));
        }
        return levels;
    }

    Repeater {
        model: root.count

        delegate: Rectangle {
            required property int index

            readonly property real fraction: (index + 0.5) / root.count
            readonly property real level: root.levels[index] || 0

            visible: root.rendering && level > 0.003
            width: Math.max(1, root.width / root.count * 0.72)
            height: Math.max(2, level * root.height)
            x: (index + 0.5) * root.width / root.count - width / 2
            y: root.height - height
            radius: Math.min(width / 2, 3)
            color: root.theme.spectrumColor(fraction)
        }
    }
}
