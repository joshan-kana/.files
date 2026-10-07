import QtQuick

Item {
    id: root

    required property QtObject spectrum
    required property QtObject theme
    required property var frequencyScale

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);

            const values = root.spectrum.bands || [];
            if (values.length < 2)
                return;

            const points = [];
            for (let source = 0; source < values.length; source += 2) {
                const next = Math.min(values.length - 1, source + 1);
                const raw = Math.max(values[source] || 0, values[next] || 0);
                const level = Math.pow(Math.max(0, Math.min(1, raw)), 0.82);
                const t = source / Math.max(1, values.length - 1);
                points.push({
                    x: root.frequencyScale.fromNormalized(t) * width,
                    y: height - Math.max(2, level * height * 0.92)
                });
            }

            if (points.length < 2)
                return;

            function traceCurve() {
                ctx.beginPath();
                ctx.moveTo(points[0].x, points[0].y);
                for (let index = 1; index < points.length - 1; index++) {
                    const current = points[index];
                    const next = points[index + 1];
                    const midX = (current.x + next.x) / 2;
                    const midY = (current.y + next.y) / 2;
                    ctx.quadraticCurveTo(current.x, current.y, midX, midY);
                }
                const last = points[points.length - 1];
                ctx.lineTo(last.x, last.y);
            }

            traceCurve();
            const last = points[points.length - 1];
            ctx.lineTo(last.x, height);
            ctx.lineTo(points[0].x, height);
            ctx.closePath();
            const fill = ctx.createLinearGradient(0, 0, 0, height);
            fill.addColorStop(0, Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28));
            fill.addColorStop(1, Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.02));
            ctx.fillStyle = fill;
            ctx.fill();

            traceCurve();
            ctx.strokeStyle = Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.92);
            ctx.lineWidth = 2.2;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.stroke();
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
