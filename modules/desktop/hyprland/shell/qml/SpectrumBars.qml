import QtQuick

Item {
    id: root

    required property QtObject spectrum
    required property QtObject theme
    required property var frequencyScale

    property int barCount: 48

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);

            const values = root.spectrum.bands || [];
            if (values.length === 0)
                return;

            const count = Math.min(root.barCount, Math.ceil(values.length / 2));
            if (count < 1)
                return;

            const centers = [];
            const sources = [];
            for (let index = 0; index < count; index++) {
                const source = Math.min(values.length - 1, index * 2);
                const t = source / Math.max(1, values.length - 1);
                sources.push(source);
                centers.push(root.frequencyScale.fromNormalized(t) * width);
            }

            for (let index = 0; index < count; index++) {
                const source = sources[index];
                const nextSource = Math.min(values.length - 1, source + 1);
                const raw = Math.max(values[source] || 0, values[nextSource] || 0);
                const level = Math.pow(Math.max(0, Math.min(1, raw)), 0.88);
                const barHeight = Math.max(2, level * height);
                const center = centers[index];
                const leftEdge = index === 0 ? 0 : (centers[index - 1] + center) / 2;
                const rightEdge = index === count - 1 ? width : (center + centers[index + 1]) / 2;
                const cellWidth = Math.max(1, rightEdge - leftEdge);
                const barWidth = Math.max(1, cellWidth * 0.70);
                const x = Math.max(0, Math.min(width - barWidth, center - barWidth / 2));
                const y = height - barHeight;

                const mix = count <= 1 ? 0 : index / (count - 1);
                const r = theme.accent.r * (1 - mix) + theme.positive.r * mix;
                const g = theme.accent.g * (1 - mix) + theme.positive.g * mix;
                const b = theme.accent.b * (1 - mix) + theme.positive.b * mix;
                ctx.fillStyle = Qt.rgba(r, g, b, 0.95);

                const radius = Math.min(barWidth / 2, 3);
                ctx.beginPath();
                ctx.moveTo(x + radius, y);
                ctx.lineTo(x + barWidth - radius, y);
                ctx.quadraticCurveTo(x + barWidth, y, x + barWidth, y + radius);
                ctx.lineTo(x + barWidth, height);
                ctx.lineTo(x, height);
                ctx.lineTo(x, y + radius);
                ctx.quadraticCurveTo(x, y, x + radius, y);
                ctx.closePath();
                ctx.fill();
            }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Connections {
        target: root.spectrum

        function onBandsChanged() {
            canvas.requestPaint();
        }
    }
}
