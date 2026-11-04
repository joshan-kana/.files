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
        property string wallpaperResizeMode: "fit"
        property string wallpaperTargetOutput: ""
        property bool musicReactiveEnabled: false
        property bool barVisible: true
        property bool frameVisible: true
        property bool windowTransparencyEnabled: false
        property bool shellGlassEnabled: false
        property real windowOpacity: 0.82
        property real glassOpacity: 0.70
        property string mediaVisualizerMode: "bars"
        property bool mediaLyricsVisible: false
        property int mediaSeekSeconds: 10
    }

    readonly property bool wallpaperSpectrumEnabled: saved.wallpaperSpectrumEnabled
    readonly property string wallpaperResizeMode: saved.wallpaperResizeMode === "crop" ? "crop" : "fit"
    readonly property string wallpaperTargetOutput: saved.wallpaperTargetOutput
    readonly property bool musicReactiveEnabled: saved.musicReactiveEnabled
    readonly property bool barVisible: saved.barVisible
    readonly property bool frameVisible: saved.frameVisible
    readonly property bool windowTransparencyEnabled: saved.windowTransparencyEnabled
    readonly property bool shellGlassEnabled: saved.shellGlassEnabled
    readonly property real windowOpacity: Math.max(0.50, Math.min(1, saved.windowOpacity))
    readonly property real glassOpacity: Math.max(0.35, Math.min(0.95, saved.glassOpacity))
    readonly property string mediaVisualizerMode: saved.mediaVisualizerMode === "curve" ? "curve" : "bars"
    readonly property bool mediaLyricsVisible: saved.mediaLyricsVisible
    readonly property var seekIntervals: [5, 10, 15, 30, 60]
    readonly property int mediaSeekSeconds: seekIntervals.includes(saved.mediaSeekSeconds) ? saved.mediaSeekSeconds : 10

    // Preloaded panels retain their Wayland layers while closed, but an
    // invisible surface must not force compositor blur of the live wallpaper.
    property bool frameGlassExposed: false
    property bool expansionGlassExposed: false
    property bool modalGlassExposed: false
    property bool notificationGlassExposed: false
    property bool osdGlassExposed: false
    property bool resizeGlassExposed: false

    // The frame and connected islands occupy separate Wayland layers.
    // Both need masked blur; neither is a substitute for the other.
    onBarVisibleChanged: applyGlassRule("linux-desktop-shell-glass", "^linux-desktop-bar$", barVisible)
    onFrameGlassExposedChanged: {
        applyGlassRule("linux-desktop-shell-glass-frame", "^linux-desktop-frame$", frameGlassExposed);
        applyGlassRule("linux-desktop-shell-glass", "^linux-desktop-bar$", barVisible);
    }
    onExpansionGlassExposedChanged: applyGlassRule("linux-desktop-shell-glass-expansion", "^linux-desktop-expansion$", expansionGlassExposed)
    onModalGlassExposedChanged: applyGlassRule("linux-desktop-shell-glass-modal", "^linux-desktop-modal$", modalGlassExposed)
    onNotificationGlassExposedChanged: applyGlassRule("linux-desktop-shell-glass-notification", "^linux-desktop-notification-popup$", notificationGlassExposed)
    onOsdGlassExposedChanged: applyGlassRule("linux-desktop-shell-glass-osd", "^linux-desktop-osd$", osdGlassExposed)
    onResizeGlassExposedChanged: applyGlassRule("linux-desktop-shell-glass-resize", "^linux-desktop-resize-controls$", resizeGlassExposed)

    function resetToDeclared(): void {
        const defaults = {
            wallpaperSpectrumEnabled: false,
            wallpaperResizeMode: "fit",
            wallpaperTargetOutput: "",
            musicReactiveEnabled: false,
            barVisible: true,
            frameVisible: true,
            windowTransparencyEnabled: false,
            shellGlassEnabled: false,
            windowOpacity: 0.82,
            glassOpacity: 0.70,
            mediaVisualizerMode: "bars",
            mediaLyricsVisible: false,
            mediaSeekSeconds: 10
        };
        for (const key of Object.keys(defaults)) {
            saved[key] = defaults[key];
            saved.setValue(key, defaults[key]);
        }
        saved.sync();
        windowOpacityApply.stop();
        applyWindowTransparency();
        applyShellGlass();
    }

    function setWallpaperTargetOutput(output: string): void {
        if (output.length === 0 || wallpaperTargetOutput === output)
            return;
        saved.wallpaperTargetOutput = output;
        saved.setValue("wallpaperTargetOutput", output);
        saved.sync();
    }

    function toggleWallpaperResizeMode(): void {
        saved.wallpaperResizeMode = wallpaperResizeMode === "fit" ? "crop" : "fit";
        saved.setValue("wallpaperResizeMode", saved.wallpaperResizeMode);
        saved.sync();
    }

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

    function toggleFrame(): void {
        saved.frameVisible = !saved.frameVisible;
        saved.setValue("frameVisible", saved.frameVisible);
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
            if (event.name === "configreloaded") {
                appearance.applyWindowTransparency();
                appearance.applyShellGlass();
            }
        }
    }

    // The compositor command is coalesced while dragging, rather than
    // launching a hyprctl process for every pointer-motion event.
    property Timer windowOpacityApply: Timer {
        interval: 65
        repeat: false
        onTriggered: appearance.applyWindowTransparency()
    }

    function applyWindowTransparency(): void {
        if (runtime.hyprctl.length === 0)
            return;
        const opacity = (windowTransparencyEnabled ? windowOpacity : 1).toFixed(2);
        Quickshell.execDetached([runtime.hyprctl, "eval", "hl.config({ decoration = { active_opacity = " + opacity + ", inactive_opacity = " + opacity + " } })"]);
    }

    function setWindowOpacity(value: real): void {
        const next = Math.round(Math.max(0.50, Math.min(1, value)) * 100) / 100;
        if (next === windowOpacity && windowTransparencyEnabled)
            return;
        saved.windowOpacity = next;
        saved.windowTransparencyEnabled = true;
        saved.setValue("windowOpacity", next);
        saved.setValue("windowTransparencyEnabled", true);
        saved.sync();
        windowOpacityApply.restart();
    }

    function setGlassOpacity(value: real): void {
        const next = Math.round(Math.max(0.35, Math.min(0.95, value)) * 100) / 100;
        if (next === glassOpacity && shellGlassEnabled)
            return;
        const wasEnabled = shellGlassEnabled;
        saved.glassOpacity = next;
        saved.shellGlassEnabled = true;
        saved.setValue("glassOpacity", next);
        saved.setValue("shellGlassEnabled", true);
        saved.sync();
        // Alpha is a live QML theme binding. Only a newly enabled glass mode
        // needs Hyprland blur rules; dragging never spawns seven processes.
        if (!wasEnabled)
            applyShellGlass();
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
        applyGlassRule("linux-desktop-shell-glass-frame", "^linux-desktop-frame$", frameGlassExposed);
        applyGlassRule("linux-desktop-shell-glass-expansion", "^linux-desktop-expansion$", expansionGlassExposed);
        applyGlassRule("linux-desktop-shell-glass-modal", "^linux-desktop-modal$", modalGlassExposed);
        applyGlassRule("linux-desktop-shell-glass-notification", "^linux-desktop-notification-popup$", notificationGlassExposed);
        applyGlassRule("linux-desktop-shell-glass-osd", "^linux-desktop-osd$", osdGlassExposed);
        applyGlassRule("linux-desktop-shell-glass-resize", "^linux-desktop-resize-controls$", resizeGlassExposed);
    }

    function toggleShellGlass(): void {
        saved.shellGlassEnabled = !saved.shellGlassEnabled;
        saved.setValue("shellGlassEnabled", saved.shellGlassEnabled);
        saved.sync();
        applyShellGlass();
    }

    function adjustMediaSeek(direction: int): void {
        const current = seekIntervals.indexOf(mediaSeekSeconds);
        const index = Math.max(0, Math.min(seekIntervals.length - 1, current + direction));
        if (index === current)
            return;
        saved.mediaSeekSeconds = seekIntervals[index];
        saved.setValue("mediaSeekSeconds", saved.mediaSeekSeconds);
        saved.sync();
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
