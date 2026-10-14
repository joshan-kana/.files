import QtQuick
import Quickshell
import Qt.labs.settings

// One persistent owner for user-selected visual modes. These are preferences,
// not session activity; the running view reads them rather than holding copies.
QtObject {
    id: appearance
    required property RuntimeConfig runtime

    property Settings settings: Settings {
        id: saved
        fileName: Quickshell.env("HOME") + "/.config/linux-desktop/preferences.ini"
        category: "Appearance"
        property bool wallpaperSpectrumEnabled: false
        property bool musicReactiveEnabled: false
        property bool barVisible: true
        property bool windowTransparencyEnabled: false
        property string mediaVisualizerMode: "bars"
        property bool mediaLyricsVisible: false
    }

    readonly property bool wallpaperSpectrumEnabled: saved.wallpaperSpectrumEnabled
    readonly property bool musicReactiveEnabled: saved.musicReactiveEnabled
    readonly property bool barVisible: saved.barVisible
    readonly property bool windowTransparencyEnabled: saved.windowTransparencyEnabled
    readonly property string mediaVisualizerMode: saved.mediaVisualizerMode === "curve" ? "curve" : "bars"
    readonly property bool mediaLyricsVisible: saved.mediaLyricsVisible

    function toggleWallpaperSpectrum(): void {
        saved.wallpaperSpectrumEnabled = !saved.wallpaperSpectrumEnabled;
        saved.setValue("wallpaperSpectrumEnabled", saved.wallpaperSpectrumEnabled);
        saved.sync();
    }

    function toggleMusicReactive(): void {
        saved.musicReactiveEnabled = !saved.musicReactiveEnabled;
        saved.setValue("musicReactiveEnabled", saved.musicReactiveEnabled);
        saved.sync();
    }

    function toggleBar(): void {
        saved.barVisible = !saved.barVisible;
        saved.setValue("barVisible", saved.barVisible);
        saved.sync();
    }

    // Keep the compositor in sync with the persisted state even after a
    // Quickshell crash or a new Hyprland session.
    Component.onCompleted: applyWindowTransparency()

    // The runtime's tool path arrives from a Nix-generated JSON file. On
    // startup it can become available after this component completes; replay
    // the saved preference when that path changes, without polling or sleeps.
    property Connections runtimeChanges: Connections {
        target: appearance.runtime
        function onHyprctlChanged(): void {
            appearance.applyWindowTransparency();
        }
    }

    function applyWindowTransparency(): void {
        if (runtime.hyprctl.length === 0)
            return;
        const opacity = windowTransparencyEnabled ? "0.82" : "1.0";
        Quickshell.execDetached([runtime.hyprctl, "eval", "hl.config({ decoration = { active_opacity = " + opacity + ", inactive_opacity = " + opacity + " } })"]);
    }

    function toggleWindowTransparency(): void {
        saved.windowTransparencyEnabled = !saved.windowTransparencyEnabled;
        saved.setValue("windowTransparencyEnabled", saved.windowTransparencyEnabled);
        saved.sync();
        applyWindowTransparency();
    }

    function toggleMediaVisualizer(): void {
        saved.mediaVisualizerMode = mediaVisualizerMode === "bars" ? "curve" : "bars";
        saved.setValue("mediaVisualizerMode", saved.mediaVisualizerMode);
        saved.sync();
    }

    function toggleMediaLyrics(): void {
        saved.mediaLyricsVisible = !saved.mediaLyricsVisible;
        saved.setValue("mediaLyricsVisible", saved.mediaLyricsVisible);
        saved.sync();
    }
}
