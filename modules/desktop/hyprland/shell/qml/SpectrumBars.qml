pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root

    required property SpectrumState spectrum
    required property Theme theme
    required property SpectrumScale frequencyScale

    property int barCount: 48
    readonly property var values: spectrum.bands || []
    readonly property int count: Math.min(barCount, values.length)

    // The analyser provides logarithmically spaced bands. Equal-width cells
    // keep a uniform visual rhythm; cache their inverse-warped boundaries so
    // 120 Hz audio updates only resample levels, not the frequency layout.
    readonly property var bandEdges: {
        const edges = [];
        for (let i = 0; i <= count; i++)
            edges.push(frequencyScale.toNormalized(i / Math.max(1, count)));
        return edges;
    }

    function levelFor(index: int): real {
        if (!count)
            return 0;

        const first = Math.max(0, Math.floor(bandEdges[index] * (values.length - 1)));
        const last = Math.min(values.length - 1, Math.ceil(bandEdges[index + 1] * (values.length - 1)));
        let peak = 0;
        for (let sample = first; sample <= last; sample++)
            peak = Math.max(peak, values[sample] || 0);
        return Math.pow(Math.max(0, Math.min(1, peak)), 0.88);
    }

    Repeater {
        model: root.count

        delegate: Rectangle {
            required property int index

            readonly property real fraction: (index + 0.5) / root.count
            readonly property real level: root.levelFor(index)

            visible: root.spectrum.hasEnergy && level > 0.003
            width: Math.max(1, root.width / root.count * 0.72)
            height: Math.max(2, level * root.height)
            x: (index + 0.5) * root.width / root.count - width / 2
            y: root.height - height
            radius: Math.min(width / 2, 3)
            color: root.theme.spectrumColor(fraction)
        }
    }
}
