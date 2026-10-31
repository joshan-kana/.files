pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Four small surfaces frame the monitor without a fullscreen blur layer.
// Wallpaper and applications remain visible and interactive through the cavity.
Variants {
    id: frames

    required property Theme theme
    required property ShellExpansionState expansionState
    property bool enabled: true
    property real hubTop: 74
    property real hubBottom: 1000
    readonly property real thickness: 13
    readonly property real rounding: 36
    readonly property color surfaceColor: theme.blend(theme.materialContainerHigh, theme.accent, 0.09)

    model: {
        const items = [];
        for (const screen of Quickshell.screens) {
            for (const edge of ["top", "bottom", "left", "right"])
                items.push({
                    screen,
                    edge
                });
        }
        return items;
    }

    delegate: PanelWindow {
        id: strip
        required property var modelData
        readonly property bool side: modelData.edge === "left" || modelData.edge === "right"
        readonly property bool topEdge: modelData.edge === "top"
        readonly property bool bottomEdge: modelData.edge === "bottom"
        readonly property bool rightEdge: modelData.edge === "right"
        readonly property bool leftEdge: modelData.edge === "left"
        readonly property bool joined: frames.expansionState.hasCurrent && (!frames.expansionState.screen || frames.expansionState.screen === screen)
        readonly property var monitor: Hyprland.monitorFor(screen)
        readonly property bool fullscreen: monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false
        screen: modelData.screen
        visible: frames.enabled && !fullscreen
        color: "transparent"
        focusable: false
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: side ? (leftEdge ? frames.thickness + frames.rounding : frames.thickness) : (screen ? screen.width : 1)
        implicitHeight: side ? Math.max(1, screen ? screen.height : 1) : frames.thickness + frames.rounding
        anchors {
            top: strip.topEdge || strip.side
            bottom: strip.bottomEdge
            left: strip.topEdge || strip.bottomEdge || strip.modelData.edge === "left"
            right: strip.rightEdge
        }
        margins {
            top: 0
        }

        WlrLayershell.namespace: "linux-desktop-perimeter-" + strip.modelData.edge
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {
            item: Item {
                width: 0
                height: 0
            }
        }

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: strip.topEdge ? parent.top : undefined
                bottom: strip.bottomEdge ? parent.bottom : undefined
            }
            width: strip.side ? frames.thickness : parent.width
            height: strip.side ? parent.height : frames.thickness
            color: frames.surfaceColor
        }

        FrameCorner {
            visible: strip.topEdge || strip.bottomEdge
            rounding: frames.rounding
            position: strip.topEdge ? 0 : 2
            surfaceColor: frames.surfaceColor
            x: frames.thickness
            y: strip.topEdge ? frames.thickness : 0
        }
        FrameCorner {
            visible: strip.topEdge || strip.bottomEdge
            rounding: frames.rounding
            position: strip.topEdge ? 1 : 3
            surfaceColor: frames.surfaceColor
            x: strip.width - frames.thickness - width
            y: strip.topEdge ? frames.thickness : 0
        }
        FrameCorner {
            visible: strip.leftEdge && strip.joined
            rounding: frames.rounding
            position: 2
            surfaceColor: frames.surfaceColor
            x: frames.thickness
            y: Math.max(frames.thickness + frames.rounding, frames.hubTop - frames.rounding)
        }
        FrameCorner {
            visible: strip.leftEdge && strip.joined
            rounding: frames.rounding
            position: 0
            surfaceColor: frames.surfaceColor
            x: frames.thickness
            y: Math.min(strip.height - frames.thickness - frames.rounding * 2, frames.hubBottom)
        }
    }
}
