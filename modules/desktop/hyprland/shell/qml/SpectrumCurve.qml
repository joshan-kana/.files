pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    required property SpectrumState spectrum
    required property Theme theme
    required property SpectrumScale frequencyScale

    readonly property var geometry: {
        const values = spectrum.displayBands || [];
        if (values.length < 2)
            return {
                outline: "",
                filled: ""
            };

        const points = [];
        for (let source = 0; source < values.length; ++source) {
            const raw = values[source] || 0;
            points.push({
                x: frequencyScale.fromNormalized(source / Math.max(1, values.length - 1)) * width,
                y: height - Math.max(2, Math.pow(Math.max(0, Math.min(1, raw)), 0.82) * height * 0.92)
            });
        }
        if (points.length < 2)
            return {
                outline: "",
                filled: ""
            };

        let outline = "M " + points[0].x + " " + points[0].y;
        // Directly connect frequency samples. Quadratic midpoint curves were
        // rounding separate spectral peaks into broad, indistinct hills.
        for (let i = 1; i < points.length; i++)
            outline += " L " + points[i].x + " " + points[i].y;
        const last = points[points.length - 1];
        return {
            outline,
            filled: outline + " L " + last.x + " " + height + " L " + points[0].x + " " + height + " Z"
        };
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.geometry.outline.length > 0

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: root.height
                GradientStop {
                    position: 0
                    color: Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.28)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.02)
                }
            }
            PathSvg {
                path: root.geometry.filled
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.92)
            strokeWidth: 2.2
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: root.geometry.outline
            }
        }
    }
}
