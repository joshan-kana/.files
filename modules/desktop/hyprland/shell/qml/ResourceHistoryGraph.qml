pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: graph
    required property RuntimeConfig runtime
    required property Theme theme
    required property string label
    required property string currentText
    required property color graphColor
    required property var values
    required property real maximum
    required property int sampleLimit

    implicitHeight: 54

    onValuesChanged: plot.requestPaint()
    onMaximumChanged: plot.requestPaint()
    onGraphColorChanged: plot.requestPaint()
    onSampleLimitChanged: plot.requestPaint()

    Row {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: 16
        Text {
            width: parent.width - current.width
            text: graph.label
            color: graph.theme.textMuted
            font.family: graph.runtime.fontMono
            font.pixelSize: graph.theme.fontSize(10)
            font.weight: Font.DemiBold
        }
        Text {
            id: current
            text: graph.currentText
            color: graph.graphColor
            font.family: graph.runtime.fontMono
            font.pixelSize: graph.theme.fontSize(10)
            font.weight: Font.DemiBold
        }
    }

    Canvas {
        id: plot
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            topMargin: 18
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext('2d');
            ctx.clearRect(0, 0, width, height);
            if (width < 2 || height < 2)
                return;

            const widthInner = Math.max(1, width - 3);
            const heightInner = Math.max(1, height - 4);
            ctx.lineWidth = 1;
            ctx.strokeStyle = Qt.rgba(graph.theme.textMuted.r, graph.theme.textMuted.g, graph.theme.textMuted.b, 0.12);
            for (let fraction = 0; fraction <= 1; fraction += 0.5) {
                const y = 2 + heightInner * fraction;
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(widthInner, y);
                ctx.stroke();
            }

            // Preserve elapsed-time meaning during warm-up: two samples
            // represent two samples, not an entire one-minute history.
            const series = graph.values || [];
            const count = Math.min(series.length, graph.sampleLimit);
            if (count === 0 || graph.maximum <= 0)
                return;
            const start = Math.max(0, series.length - count);
            const scale = Math.max(1, graph.sampleLimit - 1);
            const point = index => {
                const value = Number(series[start + index]);
                const fraction = Number.isFinite(value) ? Math.max(0, Math.min(1, value / graph.maximum)) : 0;
                return {
                    x: (graph.sampleLimit - count + index) / scale * widthInner,
                    y: 2 + heightInner * (1 - fraction)
                };
            };
            const first = point(0);
            const last = point(count - 1);
            ctx.beginPath();
            ctx.moveTo(first.x, first.y);
            for (let i = 1; i < count; ++i) {
                const next = point(i);
                ctx.lineTo(next.x, next.y);
            }
            if (count > 1) {
                ctx.lineTo(last.x, heightInner + 2);
                ctx.lineTo(first.x, heightInner + 2);
                ctx.closePath();
                ctx.fillStyle = Qt.rgba(graph.graphColor.r, graph.graphColor.g, graph.graphColor.b, 0.14);
                ctx.fill();
            }
            ctx.beginPath();
            ctx.moveTo(first.x, first.y);
            for (let i = 1; i < count; ++i) {
                const next = point(i);
                ctx.lineTo(next.x, next.y);
            }
            ctx.strokeStyle = graph.graphColor;
            ctx.lineWidth = 2;
            ctx.lineJoin = 'round';
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(last.x, last.y, 2.7, 0, Math.PI * 2);
            ctx.fillStyle = graph.graphColor;
            ctx.fill();
        }
    }
}
