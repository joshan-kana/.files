import QtQuick
import QtQuick.Shapes

Item {
    id: glyph

    property color color: "white"

    Shape {
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: Math.min(glyph.width, glyph.height) / 24
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: glyph.color
            strokeWidth: 1.9
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: "M5 11 H19 Q21 11 21 13 V20 Q21 22 19 22 H5 Q3 22 3 20 V13 Q3 11 5 11 Z M7 11 V7 A5 5 0 0 1 17 7 V11"
            }
        }
    }
}
