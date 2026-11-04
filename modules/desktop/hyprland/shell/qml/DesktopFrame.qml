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
    // Only blur the shared frame while at least one screen exposes it.
    // Fullscreen clients hide the frame without destroying its Wayland layer.
    readonly property bool glassExposed: enabled && Quickshell.screens.some(screen => {
        const monitor = Hyprland.monitorFor(screen);
        return !(monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false);
    })
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
    // Keep the one-pixel frame outline readable against wallpaper glass.
    // Audio colours belong in the continuous surface fill, not the stroke.
    readonly property color reactiveBorder: Qt.rgba(theme.subtleBorder.r, theme.subtleBorder.g, theme.subtleBorder.b, theme.shellGlassEnabled ? theme.glassContourBorder.a : theme.subtleBorder.a)
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
        readonly property bool reactiveActive: frame.theme.musicReactiveEnabled && frame.theme.musicReactiveWash > 0.02
        readonly property bool busyHere: frame.busy && (!frame.busyScreen || frame.busyScreen === modelData)
        SquircleGeometry {
            id: squircleGeometry
        }
        // Collect reactive sources cheaply, then build the expensive shared
        // outline once after all same-turn geometry changes have settled.
        readonly property var geometryInputs: [modelData ? modelData.width : 1, modelData ? modelData.height : 1, frame.thickness, frame.rounding, frame.theme.squircleExponent, frame.barVisible ? (frame.islands[modelData.name] || []) : [], frame.hubScreen === modelData ? frame.hub : null, frame.toastScreen === modelData ? frame.toast : [], squircleGeometry, frame.osdScreen === modelData ? frame.osd : null, frame.resizeScreen === modelData ? frame.resize : null, output.busyHere]
        property var geometry: ({
                inner: "",
                fill: "",
                hoverFill: "",
                pressedFill: "",
                length: 0,
                points: []
            })

        function rebuildGeometry(): void {
            const args = geometryInputs;
            output.geometry = FrameGeometry.contour(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11]);
        }

        onGeometryInputsChanged: Qt.callLater(output.rebuildGeometry)
        Component.onCompleted: output.rebuildGeometry()

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
                    // Keep content opaque, but let the compositor sample the
                    // wallpaper through the shared frame's actual silhouette.
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        // The frame is already correctly clipped by this
                        // odd-even path. Animate existing stop colours, not
                        // separate meshes that can cross its inside boundary.
                        x1: 0
                        y1: 0
                        x2: drawing.width
                        y2: 0
                        GradientStop {
                            position: 0
                            color: frame.theme.reactiveFrameMotionColor(0, output.reactiveActive)
                        }
                        GradientStop {
                            position: 0.125
                            color: frame.theme.reactiveFrameMotionColor(0.125, output.reactiveActive)
                        }
                        GradientStop {
                            position: 0.25
                            color: frame.theme.reactiveFrameMotionColor(0.25, output.reactiveActive)
                        }
                        GradientStop {
                            position: 0.375
                            color: frame.theme.reactiveFrameMotionColor(0.375, output.reactiveActive)
                        }
                        GradientStop {
                            position: 0.5
                            color: frame.theme.reactiveFrameMotionColor(0.5, output.reactiveActive)
                        }
                        GradientStop {
                            position: 0.625
                            color: frame.theme.reactiveFrameMotionColor(0.625, output.reactiveActive)
                        }
                        GradientStop {
                            position: 0.75
                            color: frame.theme.reactiveFrameMotionColor(0.75, output.reactiveActive)
                        }
                        GradientStop {
                            position: 0.875
                            color: frame.theme.reactiveFrameMotionColor(0.875, output.reactiveActive)
                        }
                        GradientStop {
                            position: 1
                            color: frame.theme.reactiveFrameMotionColor(1, output.reactiveActive)
                        }
                    }
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
