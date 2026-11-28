pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// One bottom-layer surface keeps the spectrum above the atmosphere regardless
// of which effect was enabled first. With atmosphere off, retain the small
// spectrum region instead of allocating a screen-sized transparent buffer.
Variants {
    id: visuals

    required property RuntimeConfig runtime
    required property SpectrumState spectrum
    required property Theme theme
    required property AppearancePreferences appearance
    required property MusicReactiveState reactive
    required property bool locked
    property bool enabled: false
    required property Motion motion

    // ScreenRouter refreshes fullscreen IPC state on compositor events.
    readonly property var eligibleScreens: !locked && (appearance.atmosphereEnabled || enabled) ? Quickshell.screens.filter(screen => !(Hyprland.monitorFor(screen)?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false)) : []
    // The silent wallpaper needs audio to discover the first beat, but not
    // while every output is locked or unavailable behind exclusive fullscreen.
    readonly property bool demandEligible: enabled && eligibleScreens.length > 0
    model: eligibleScreens

    delegate: Scope {
        id: output
        required property var modelData

        // Wayland layer-shell can retain obsolete margins when anchors and
        // margins change in the same commit. Map a fresh surface with fixed
        // geometry when switching between the two compositions.
        LazyLoader {
            active: visuals.appearance.atmosphereEnabled
            component: EffectWindow {
                screen: output.modelData
                atmosphereActive: true
            }
        }
        LazyLoader {
            active: !visuals.appearance.atmosphereEnabled && visuals.enabled && visuals.spectrum.hasEnergy
            component: EffectWindow {
                screen: output.modelData
                atmosphereActive: false
            }
        }
    }

    component EffectWindow: PanelWindow {
        id: wallpaperLayer

        required property bool atmosphereActive
        readonly property bool spectrumActive: visuals.enabled && visuals.spectrum.hasEnergy
        readonly property int spectrumWidth: Math.max(1, screen ? screen.width * 0.88 : 1)
        readonly property int spectrumHeight: Math.max(1, screen ? Math.min(screen.height * 0.38, 560) : 1)
        readonly property int spectrumBottom: screen ? Math.max(50, screen.height * 0.065) : 0
        visible: true
        focusable: false
        exclusionMode: ExclusionMode.Ignore
        color: atmosphereActive && visuals.appearance.atmosphereBackdrop ? visuals.theme.background : "transparent"
        implicitWidth: atmosphereActive && screen ? screen.width : spectrumWidth
        implicitHeight: atmosphereActive && screen ? screen.height : spectrumHeight

        anchors {
            top: wallpaperLayer.atmosphereActive
            bottom: true
            left: true
            right: wallpaperLayer.atmosphereActive
        }
        margins {
            bottom: wallpaperLayer.atmosphereActive ? 0 : wallpaperLayer.spectrumBottom
            left: wallpaperLayer.atmosphereActive || !screen ? 0 : Math.max(0, (screen.width - wallpaperLayer.spectrumWidth) / 2)
        }

        WlrLayershell.namespace: "desktop-shell-wallpaper-spectrum"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region {
            item: Item {
                width: 0
                height: 0
            }
        }

        Loader {
            anchors.fill: parent
            active: wallpaperLayer.atmosphereActive && wallpaperLayer.visible
            sourceComponent: AtmosphereEffect {
                runtime: visuals.runtime
                theme: visuals.theme
                motion: visuals.motion
                mode: visuals.appearance.atmosphereMode
                intensity: visuals.appearance.atmosphereOpacity
                speed: visuals.appearance.atmosphereSpeed
                reactive: visuals.reactive
                audioSync: visuals.appearance.atmosphereAudioEnabled
            }
        }

        SpectrumVisualizer {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: wallpaperLayer.atmosphereActive ? wallpaperLayer.spectrumBottom : 0
            width: wallpaperLayer.spectrumWidth
            height: wallpaperLayer.spectrumHeight
            visible: wallpaperLayer.spectrumActive
            spectrum: visuals.spectrum
            theme: visuals.theme
            motion: visuals.motion
            surfaceKey: "wallpaperVisualizerMode"
            drivesDemand: false
            enabled: wallpaperLayer.visible && wallpaperLayer.spectrumActive
        }
    }
}
