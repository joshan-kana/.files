pragma ComponentBehavior: Bound
import QtQuick
import LinuxDesktop.Visuals 1.0

Item {
    id: root

    required property SpectrumState spectrum
    required property Theme theme
    required property SpectrumScale frequencyScale

    property int barCount: 48
    // Hidden, prewarmed hub pages retain their models but do no visualizer
    // calculations. Enabled is inherited from the owning inactive Loader.
    readonly property bool rendering: enabled && visible && opacity > 0 && width > 0 && height > 0 && spectrum.hasEnergy
    readonly property int count: Math.min(barCount, spectrum.targetBands.length)

    // Analyser bands are logarithmic. The inverse-warped sampling boundaries
    // change only when the display scale or bar count changes.
    readonly property var bandEdges: {
        const edges = [];
        for (let i = 0; i <= count; i++)
            edges.push(frequencyScale.toNormalized(i / Math.max(1, count)));
        return edges;
    }

    // The scene graph owns frame-to-frame interpolation and batched geometry.
    // These colors and frequency boundaries change only with the theme,
    // display scale or bar count, not with every audio sample.
    readonly property var palette: {
        const colors = [];
        for (let i = 0; i < count; i++)
            colors.push(theme.spectrumColor((i + 0.5) / count));
        return colors;
    }

    SpectrumBarsItem {
        anchors.fill: parent
        visible: root.rendering
        targetBands: root.spectrum.targetBands
        edges: root.bandEdges
        palette: root.palette
        lowHz: root.spectrum.lowHz
        highHz: root.spectrum.highHz
        decaying: root.spectrum.decaying
    }
}
