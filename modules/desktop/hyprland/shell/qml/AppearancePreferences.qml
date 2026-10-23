import QtQuick
import Quickshell
import Quickshell.Hyprland
import QtCore

// One persistent owner for user-selected visual modes. These are preferences,
// not session activity; the running view reads them rather than holding copies.
QtObject {
    id: appearance
    required property RuntimeConfig runtime

    property Settings settings: Settings {
        id: saved
        location: "file://" + Quickshell.env("HOME") + "/.config/linux-desktop/preferences.ini"
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

    // Preloaded panels retain their Wayland layers while closed, but an
    // invisible surface must not force compositor blur of the live wallpaper.
    property bool expansionGlassExposed: false
    property bool modalGlassExposed: false
    property bool notificationGlassExposed: false
    property bool osdGlassExposed: false

    onBarVisibleChanged: applyGlassRule("linux-desktop-shell-glass", "^linux-desktop-bar$", barVisible)
    onExpansionGlassExposedChanged: applyGlassRule("linux-desktop-shell-glass-expansion", "^linux-desktop-expansion$", expansionGlassExposed)
    onModalGlassExposedChanged: applyGlassRule("linux-desktop-shell-glass-modal", "^linux-desktop-modal$", modalGlassExposed)
    onNotificationGlassExposedChanged: applyGlassRule("linux-desktop-shell-glass-notification", "^linux-desktop-notification-popup$", notificationGlassExposed)
    onOsdGlassExposedChanged: applyGlassRule("linux-desktop-shell-glass-osd", "^linux-desktop-osd$", osdGlassExposed)

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

    function applyGlassRule(name: string, namespace: string, exposed: bool): void {
        if (runtime.hyprctl.length === 0)
            return;
        const enabled = shellGlassEnabled && exposed ? "true" : "false";
        // Sample application windows as well as bottom/background layers.
        // X-ray would drop intervening windows from the glass backdrop.
        Quickshell.execDetached([runtime.hyprctl, "eval", "hl.layer_rule({name = \"" + name + "\", match = {namespace = \"" + namespace + "\"}, blur = true, xray = false, ignore_alpha = 0.08, enabled = " + enabled + "})"]);
    }

    function applyShellGlass(): void {
        // Only visible layers need backdrop blur. Preloaded modal and hub
        // surfaces keep their fast first-open path without idle blur passes.
        applyGlassRule("linux-desktop-shell-glass", "^linux-desktop-bar$", barVisible);
        applyGlassRule("linux-desktop-shell-glass-expansion", "^linux-desktop-expansion$", expansionGlassExposed);
        applyGlassRule("linux-desktop-shell-glass-modal", "^linux-desktop-modal$", modalGlassExposed);
        applyGlassRule("linux-desktop-shell-glass-notification", "^linux-desktop-notification-popup$", notificationGlassExposed);
        applyGlassRule("linux-desktop-shell-glass-osd", "^linux-desktop-osd$", osdGlassExposed);
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
