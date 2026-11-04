pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    required property SpectrumState spectrum
    required property Theme theme
    required property SpectrumScale frequencyScale
    readonly property color curveColor: theme.spectrumColor(0.68)

    // Keep the shared QML interpolation active only while an actual curve
    // is visible. Hidden prewarmed media pages do not drive display frames.
    readonly property bool needsInterpolation: enabled && visible && opacity > 0 && width > 0 && height > 0
    property bool interpolationRegistered: false

    function syncInterpolation(): void {
        if (!spectrum || needsInterpolation === interpolationRegistered)
            return;
        spectrum.curveSubscribers += needsInterpolation ? 1 : -1;
        interpolationRegistered = needsInterpolation;
    }

    onNeedsInterpolationChanged: syncInterpolation()
    Component.onCompleted: syncInterpolation()
    Component.onDestruction: {
        if (interpolationRegistered && spectrum)
            spectrum.curveSubscribers--;
    }

    readonly property var geometry: {
        // Inactive prewarmed media views should not rebuild SVG paths while
        // another panel owns the screen. The live view retains full fidelity.
        if (!root.enabled || !root.visible || root.opacity <= 0 || !spectrum.hasEnergy)
            return {
                outline: "",
                filled: ""
            };
        const values = spectrum.bands || [];
        if (values.length < 2)
            return {
                outline: "",
                filled: ""
            };

        const points = [];
        for (let source = 0; source < values.length; source += 2) {
            const raw = Math.max(values[source] || 0, values[Math.min(source + 1, values.length - 1)] || 0);
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
        for (let i = 1; i < points.length - 1; i++) {
            const next = points[i + 1];
            outline += " Q " + points[i].x + " " + points[i].y + " " + (points[i].x + next.x) / 2 + " " + (points[i].y + next.y) / 2;
        }
        const last = points[points.length - 1];
        outline += " L " + last.x + " " + last.y;
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
                    color: Qt.rgba(root.curveColor.r, root.curveColor.g, root.curveColor.b, 0.28)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(root.curveColor.r, root.curveColor.g, root.curveColor.b, 0.02)
                }
            }
            PathSvg {
                path: root.geometry.filled
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(root.curveColor.r, root.curveColor.g, root.curveColor.b, 0.92)
            strokeWidth: 2.2
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: root.geometry.outline
            }
        }
    }
}
