pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "FrameGeometry.js" as FrameGeometry
import "OutlineTrace.js" as OutlineTrace

// A single geometric silhouette per screen: the desktop frame, bar islands,
// expanded hub and notification dock share one continuous inside boundary.
// Exclusion zones are separate one-pixel surfaces with no input area; the
// compositor remains the sole owner of dynamic window gaps.
Variants {
    id: frame

    required property Theme theme
    required property Motion motion
    property bool enabled: true
    property bool barVisible: true
    property var islands: ({})
    property var hub: null
    property var hubScreen: null
    property var toast: null
    property var toastScreen: null
    property var osd: null
    property var osdScreen: null
    property var resize: null
    property var resizeScreen: null
    property bool busy: false
    property var busyScreen: null
    readonly property real thickness: theme.frameThickness
    readonly property real rounding: theme.frameRounding
    // Music changes the shared contour's hue, never its width or opacity.
    // Theme.blend returns an opaque colour, so restore the border's alpha.
    readonly property color reactiveTint: theme.musicReactiveEnabled && motion.enabled ? theme.blend(theme.subtleBorder, theme.blend(theme.accent, theme.positive, theme.musicReactiveTreble * 0.85), Math.min(0.46, theme.musicReactiveEnergy * 0.25 + theme.musicReactiveBeat * 0.21)) : theme.subtleBorder
    readonly property color reactiveBorder: Qt.rgba(reactiveTint.r, reactiveTint.g, reactiveTint.b, theme.subtleBorder.a)
    property real progress: 0

    NumberAnimation on progress {
        running: frame.busy && frame.motion.enabled
        from: 0
        to: 1
        duration: 1900
        loops: Animation.Infinite
        easing.type: Easing.InOutSine
    }

    model: Quickshell.screens

    delegate: Scope {
        id: output
        required property var modelData
        readonly property var monitor: Hyprland.monitorFor(modelData)
        readonly property bool fullscreen: monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false
        readonly property bool exposed: frame.enabled && !fullscreen
        readonly property bool busyHere: frame.busy && (!frame.busyScreen || frame.busyScreen === modelData)
        SquircleGeometry {
            id: squircleGeometry
        }
        readonly property var geometry: FrameGeometry.contour(modelData ? modelData.width : 1, modelData ? modelData.height : 1, frame.thickness, frame.rounding, frame.theme.squircleExponent, frame.barVisible ? (frame.islands[modelData.name] || []) : [], frame.hubScreen === modelData ? frame.hub : null, frame.toastScreen === modelData ? frame.toast : [], squircleGeometry, frame.osdScreen === modelData ? frame.osd : null, frame.resizeScreen === modelData ? frame.resize : null)

        PanelWindow {
            id: drawing
            screen: output.modelData
            // Keep the compositor's backing surface stable across toggles.
            // Recreating an entire screen layer causes black texture remnants.
            visible: true
            color: "transparent"
            focusable: false
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: screen ? screen.width : 1
            implicitHeight: screen ? screen.height : 1
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            WlrLayershell.namespace: "linux-desktop-frame"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {
                item: Item {
                    width: 0
                    height: 0
                }
            }

            Shape {
                // Keep the backing layer and drawn contour alive while the
                // frame fades. Toggling Shape.visible discarded its geometry
                // instantly and made bar islands jump between visual modes.
                // After the fade finishes, remove the hidden Shape from the
                // scene graph without ever recreating the Wayland surface.
                visible: opacity > 0
                opacity: output.exposed ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: frame.motion.morph
                        easing.type: frame.motion.morphType
                        easing.bezierCurve: frame.motion.morphCurve
                    }
                }
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillRule: Qt.OddEvenFill
                    fillColor: frame.theme.background
                    strokeWidth: -1
                    PathSvg {
                        path: output.geometry.fill || "M 0 0 L 0.01 0 L 0 0.01 Z"
                    }
                }
                ShapePath {
                    fillColor: Qt.rgba(frame.theme.textStrong.r, frame.theme.textStrong.g, frame.theme.textStrong.b, 0.075)
                    strokeWidth: -1
                    PathSvg {
                        path: output.geometry.hoverFill || "M 0 0 L 0.01 0 L 0 0.01 Z"
                    }
                }
                ShapePath {
                    fillColor: Qt.rgba(frame.theme.textStrong.r, frame.theme.textStrong.g, frame.theme.textStrong.b, 0.16)
                    strokeWidth: -1
                    PathSvg {
                        path: output.geometry.pressedFill || "M 0 0 L 0.01 0 L 0 0.01 Z"
                    }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: frame.reactiveBorder
                    strokeWidth: frame.theme.borderThin
                    joinStyle: ShapePath.RoundJoin
                    PathSvg {
                        path: output.geometry.inner || "M 0 0 L 0.01 0 L 0 0.01 Z"
                    }
                }
            }

            OutlinePulse {
                anchors.fill: parent
                active: output.exposed && output.busyHere && !frame.motion.enabled
                contourPath: output.geometry.inner
                highlightColor: frame.theme.accent
                lineWidth: 2
            }

            Canvas {
                id: busyTrace
                readonly property var bounds: output.exposed && output.busyHere && frame.motion.enabled ? OutlineTrace.traceBounds(output.geometry.points, output.geometry.length, frame.progress, 0.10, 24, drawing.width, drawing.height) : null
                x: bounds ? bounds.x : 0
                y: bounds ? bounds.y : 0
                width: bounds ? bounds.width : 1
                height: bounds ? bounds.height : 1
                visible: output.exposed && output.busyHere && frame.motion.enabled
                antialiasing: true
                onPaint: {
                    if (bounds)
                        OutlineTrace.paint(getContext("2d"), output.geometry.points, output.geometry.length, frame.progress, 0.10, frame.theme.accent, 2, width, height, bounds.x, bounds.y, bounds);
                }
                onBoundsChanged: requestPaint()
                Connections {
                    target: frame
                    function onProgressChanged() {
                        busyTrace.requestPaint();
                    }
                    function onBusyChanged() {
                        busyTrace.requestPaint();
                    }
                }
                Connections {
                    target: output
                    function onGeometryChanged() {
                        busyTrace.requestPaint();
                    }
                    function onBusyHereChanged() {
                        busyTrace.requestPaint();
                    }
                }
            }
        }

        Reservation {
            active: output.exposed
            inset: frame.thickness
            anchors.left: true
        }
        Reservation {
            active: output.exposed
            inset: frame.thickness
            anchors.right: true
        }
        Reservation {
            active: output.exposed
            inset: frame.thickness
            anchors.bottom: true
        }
        Reservation {
            active: output.exposed && !frame.barVisible
            inset: frame.thickness
            anchors.top: true
        }
    }

    // Invisible, 1px layers reserve the frame inset. The bar already
    // reserves its full top height, so never stack a second top zone.
    component Reservation: PanelWindow {
        property bool active: false
        property real inset: 0
        visible: active
        screen: output.modelData
        color: "transparent"
        focusable: false
        implicitWidth: 1
        implicitHeight: 1
        exclusiveZone: active ? inset : 0
        WlrLayershell.namespace: "linux-desktop-frame-reservation"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {
            item: Item {
                width: 0
                height: 0
            }
        }
    }
}
