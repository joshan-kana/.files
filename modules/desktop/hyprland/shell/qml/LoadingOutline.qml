import QtQuick

// Adapt the live squircle geometry to the shared contour renderer.
BusyContour {
    id: outline
    required property SquircleSurface surface
    contourPath: surface.borderWidth > 0 && surface.borderColor.a > 0 ? surface.borderPathData : surface.fillPathData
}
