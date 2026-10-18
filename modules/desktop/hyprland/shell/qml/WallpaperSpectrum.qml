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
    required property Motion motion
    property bool enabled: false

    model: Quickshell.screens

    delegate: PanelWindow {
        id: layer

        required property var modelData
        screen: modelData
        visible: visuals.enabled && visuals.motion.enabled && visuals.spectrum.hasEnergy
        focusable: false
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.namespace: "linux-desktop-wallpaper-spectrum"
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
            width: parent.width * 0.88
            height: Math.min(parent.height * 0.38, 560)
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: Math.max(50, parent.height * 0.065)
            }

            SpectrumScale {
                id: frequencies
                lowHz: visuals.spectrum.lowHz
                highHz: visuals.spectrum.highHz
            }

            // Real FFT-derived values only. The soft curve adds depth without
            // a second analyser, simulated notes or an always-running scene.
            SpectrumCurve {
                anchors.fill: parent
                spectrum: visuals.spectrum
                theme: visuals.theme
                frequencyScale: frequencies
                opacity: 0.65
            }

            SpectrumBars {
                anchors.fill: parent
                spectrum: visuals.spectrum
                theme: visuals.theme
                frequencyScale: frequencies
                barCount: 64
                opacity: 0.80
            }
        }
    }
}
