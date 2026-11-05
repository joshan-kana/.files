pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    required property SpectrumState spectrum
    required property Theme theme
    required property SpectrumScale frequencyScale

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
                filled: "",
                ribbon: ""
            };
        const values = spectrum.bands || [];
        if (values.length < 2)
            return {
                outline: "",
                filled: "",
                ribbon: ""
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
                filled: "",
                ribbon: ""
            };

        let outline = "M " + points[0].x + " " + points[0].y;
        for (let i = 1; i < points.length - 1; i++) {
            const next = points[i + 1];
            outline += " Q " + points[i].x + " " + points[i].y + " " + (points[i].x + next.x) / 2 + " " + (points[i].y + next.y) / 2;
        }
        const last = points[points.length - 1];
        outline += " L " + last.x + " " + last.y;

        // A ShapePath stroke can only have one colour. Fill a thin closed
        // ribbon along the same quadratic curve so its left-to-right colour
        // comes from the same three spectrum stops as the bars and frame.
        const thickness = 2.2;
        let ribbon = outline + " L " + last.x + " " + (last.y + thickness);
        for (let i = points.length - 2; i > 0; i--) {
            const previous = points[i - 1];
            ribbon += " Q " + points[i].x + " " + (points[i].y + thickness) + " " + (points[i].x + previous.x) / 2 + " " + ((points[i].y + previous.y) / 2 + thickness);
        }
        ribbon += " L " + points[0].x + " " + (points[0].y + thickness) + " Z";
        return {
            outline,
            filled: outline + " L " + last.x + " " + height + " L " + points[0].x + " " + height + " Z",
            ribbon
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
                x2: root.width
                y2: 0
                GradientStop {
                    position: 0
                    color: Qt.rgba(root.theme.spectrumColor(0).r, root.theme.spectrumColor(0).g, root.theme.spectrumColor(0).b, 0.12)
                }
                GradientStop {
                    position: 0.5
                    color: Qt.rgba(root.theme.spectrumColor(0.5).r, root.theme.spectrumColor(0.5).g, root.theme.spectrumColor(0.5).b, 0.12)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(root.theme.spectrumColor(1).r, root.theme.spectrumColor(1).g, root.theme.spectrumColor(1).b, 0.12)
                }
            }
            PathSvg {
                path: root.geometry.filled
            }
        }
        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: root.width
                y2: 0
                GradientStop {
                    position: 0
                    color: root.theme.spectrumColor(0)
                }
                GradientStop {
                    position: 0.5
                    color: root.theme.spectrumColor(0.5)
                }
                GradientStop {
                    position: 1
                    color: root.theme.spectrumColor(1)
                }
            }
            PathSvg {
                path: root.geometry.ribbon
            }
        }
    }
}
