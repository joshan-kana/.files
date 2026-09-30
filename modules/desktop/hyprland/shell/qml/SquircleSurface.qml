import QtQuick
import QtQuick.Shapes

Item {
    id: root

    default property alias contentData: content.data

    property color fillColor: "transparent"
    property color borderColor: "transparent"
    property real borderWidth: 0
    property real cornerRadius: 28
    property real exponent: 4.5
    property int cornerSamples: 16

    readonly property string pathData: buildPath()

    function point(value: real): string {
        return Number(value).toFixed(2);
    }

    function buildCorner(cx: real, cy: real, radius: real, start: real, end: real): string {
        let points = "";
        for (let i = 1; i <= cornerSamples; i++) {
            const t = start + (end - start) * (i / cornerSamples);
            const c = Math.cos(t);
            const s = Math.sin(t);
            const px = cx + radius * Math.sign(c) * Math.pow(Math.abs(c), 2 / exponent);
            const py = cy + radius * Math.sign(s) * Math.pow(Math.abs(s), 2 / exponent);
            points += " L " + point(px) + " " + point(py);
        }
        return points;
    }

    function buildPath(): string {
        const r = Math.min(cornerRadius, width / 2, height / 2);
        if (width <= 0 || height <= 0 || r <= 0)
            return "";

        let path = "M " + point(r) + " 0";
        path += " L " + point(width - r) + " 0";
        path += buildCorner(width - r, r, r, -Math.PI / 2, 0);
        path += " L " + point(width) + " " + point(height - r);
        path += buildCorner(width - r, height - r, r, 0, Math.PI / 2);
        path += " L " + point(r) + " " + point(height);
        path += buildCorner(r, height - r, r, Math.PI / 2, Math.PI);
        path += " L 0 " + point(r);
        path += buildCorner(r, r, r, Math.PI, Math.PI * 1.5);
        path += " Z";
        return path;
    }

    Shape {
        anchors.fill: parent

        ShapePath {
            fillColor: root.fillColor
            strokeColor: root.borderColor
            strokeWidth: root.borderWidth

            PathSvg {
                path: root.pathData
            }
        }
    }

    Item {
        id: content
        anchors.fill: parent
    }
}
