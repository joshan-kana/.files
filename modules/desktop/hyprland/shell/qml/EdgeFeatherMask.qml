pragma ComponentBehavior: Bound
import QtQuick
import "EdgeFeather.js" as EdgeFeather

// A size-aware alpha texture, rendered only while Help is open or its
// viewport changes. No raster asset or per-frame edge animation is needed.
Canvas {
    id: mask
    property bool active: false
    property real feather: 40

    opacity: 0
    enabled: false
    Accessible.ignored: true
    layer.enabled: active
    renderTarget: Canvas.Image

    function invalidate(): void {
        if (active && available)
            requestPaint();
    }

    onActiveChanged: invalidate()
    onAvailableChanged: invalidate()
    onWidthChanged: invalidate()
    onHeightChanged: invalidate()
    onFeatherChanged: invalidate()

    function fillAxis(context: var, horizontal: bool): void {
        const gradient = context.createLinearGradient(0, 0, horizontal ? width : 0, horizontal ? 0 : height);
        for (const stop of EdgeFeather.gradientStops(horizontal ? width : height, feather))
            gradient.addColorStop(stop[0], Qt.rgba(1, 1, 1, stop[1]));
        context.fillStyle = gradient;
        context.fillRect(0, 0, width, height);
    }

    onPaint: {
        if (!active || width <= 0 || height <= 0)
            return;
        const context = getContext("2d");
        context.globalCompositeOperation = "source-over";
        context.clearRect(0, 0, width, height);
        fillAxis(context, true);
        context.globalCompositeOperation = "destination-in";
        fillAxis(context, false);
        context.globalCompositeOperation = "source-over";
    }
}
