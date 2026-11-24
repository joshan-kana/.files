import QtQuick
import "OutlineTrace.js" as OutlineTrace

// Adapt the live squircle geometry to the shared contour renderer.
BusyContour {
    id: outline
    required property SquircleSurface surface
    readonly property real inset: lineWidth * 1.3 + 0.5
    contourPath: surface.buildPath(inset)
    points: OutlineTrace.contour(contourPath)
    perimeter: points.length > 1 ? points[points.length - 1].at : 1
}
