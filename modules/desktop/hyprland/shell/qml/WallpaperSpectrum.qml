pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

// This transparent, non-interactive bottom layer is above awww/mpvpaper and
// below application windows. Compositor window transparency reveals it.
Variants {
    id: visuals

    required property SpectrumState spectrum
    required property Theme theme
    property bool enabled: false
    required property Motion motion

    model: Quickshell.screens

    delegate: PanelWindow {
        id: layer

        required property var modelData
        screen: modelData
        visible: visuals.enabled && visuals.spectrum.hasEnergy
        focusable: false
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        implicitWidth: Math.max(1, screen ? screen.width * 0.88 : 1)
        implicitHeight: Math.max(1, screen ? Math.min(screen.height * 0.38, 560) : 1)

        anchors {
            bottom: true
            left: true
        }
        margins {
            bottom: screen ? Math.max(50, screen.height * 0.065) : 0
            left: screen ? (screen.width - implicitWidth) / 2 : 0
        }

        WlrLayershell.namespace: "desktop-shell-wallpaper-spectrum"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Fully empty pointer region: clicks pass through to the compositor.
        mask: Region {
            item: Item {
                width: 0
                height: 0
            }
        }

        Item {
            anchors.fill: parent

            SpectrumVisualizer {
                anchors.fill: parent
                spectrum: visuals.spectrum
                theme: visuals.theme
                motion: visuals.motion
                surfaceKey: "wallpaperVisualizerMode"
                baseDensity: 64
                baseOpacity: 0.8
                drivesDemand: false
                enabled: layer.visible
            }
        }
    }
}
