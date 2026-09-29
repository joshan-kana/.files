import QtQuick

Item {
    id: root

    required property QtObject spectrum
    required property QtObject theme

    property int barCount: 48
    property real gap: 3

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

            const count = Math.min(root.barCount, Math.floor(values.length / 2));
            const totalGap = root.gap * Math.max(0, count - 1);
            const barWidth = Math.max(1, (width - totalGap) / count);
            const floorHeight = 2;

            for (let index = 0; index < count; index++) {
                const source = index * 2;
                const raw = Math.max(values[source] || 0, values[source + 1] || 0);
                const level = Math.pow(Math.max(0, Math.min(1, raw)), 0.88);
                const barHeight = Math.max(floorHeight, level * height);
                const x = index * (barWidth + root.gap);
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
