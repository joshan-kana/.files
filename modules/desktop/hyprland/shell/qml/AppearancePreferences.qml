import QtQuick
import Quickshell
import Quickshell.Hyprland
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
        property bool shellGlassEnabled: false
        property string mediaVisualizerMode: "bars"
        property bool mediaLyricsVisible: false
    }

    readonly property bool wallpaperSpectrumEnabled: saved.wallpaperSpectrumEnabled
    readonly property bool musicReactiveEnabled: saved.musicReactiveEnabled
    readonly property bool barVisible: saved.barVisible
    readonly property bool windowTransparencyEnabled: saved.windowTransparencyEnabled
    readonly property bool shellGlassEnabled: saved.shellGlassEnabled
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
    Component.onCompleted: {
        applyWindowTransparency();
        applyShellGlass();
    }

    // The runtime's tool path arrives from a Nix-generated JSON file. On
    // startup it can become available after this component completes; replay
    // the saved preference when that path changes, without polling or sleeps.
    property Connections runtimeChanges: Connections {
        target: appearance.runtime
        function onHyprctlChanged(): void {
            appearance.applyWindowTransparency();
            appearance.applyShellGlass();
        }
    }

    // A compositor reload replaces runtime layer rules. Reapply the saved
    // preference when Hyprland reports completion, without polling.
    property Connections compositorReload: Connections {
        target: Hyprland
        function onRawEvent(event): void {
            if (event.name === "configreloaded")
                appearance.applyShellGlass();
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

    function applyShellGlass(): void {
        if (runtime.hyprctl.length === 0)
            return;
        // Reuse one named compositor rule across reloads and toggles. The
        // alpha threshold keeps transparent parts of large viewports sharp.
        const enabled = shellGlassEnabled ? "true" : "false";
        Quickshell.execDetached([runtime.hyprctl, "eval", "hl.layer_rule({name = \"linux-desktop-shell-glass\", match = {namespace = \"^linux-desktop-(bar|expansion|modal|notification-popup|osd)$\"}, blur = true, ignore_alpha = 0.08, enabled = " + enabled + "})"]);
    }

    function toggleShellGlass(): void {
        saved.shellGlassEnabled = !saved.shellGlassEnabled;
        saved.setValue("shellGlassEnabled", saved.shellGlassEnabled);
        saved.sync();
        applyShellGlass();
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
