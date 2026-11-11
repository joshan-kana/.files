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
        property bool wallpaperSpectrumEnabled: appearance.runtime.appearanceDefaults.wallpaperSpectrumEnabled
        property string wallpaperResizeMode: appearance.runtime.appearanceDefaults.wallpaperResizeMode
        property string wallpaperTargetOutput: appearance.runtime.appearanceDefaults.wallpaperTargetOutput
        property bool musicReactiveEnabled: appearance.runtime.appearanceDefaults.musicReactiveEnabled
        property bool barVisible: appearance.runtime.appearanceDefaults.barVisible
        property bool frameVisible: appearance.runtime.appearanceDefaults.frameVisible
        property bool windowTransparencyEnabled: appearance.runtime.appearanceDefaults.windowTransparencyEnabled
        property bool shellGlassEnabled: appearance.runtime.appearanceDefaults.shellGlassEnabled
        property real windowOpacity: appearance.runtime.appearanceDefaults.windowOpacity
        property real glassOpacity: appearance.runtime.appearanceDefaults.glassOpacity
        property string mediaVisualizerMode: appearance.runtime.appearanceDefaults.mediaVisualizerMode
        property bool mediaLyricsVisible: appearance.runtime.appearanceDefaults.mediaLyricsVisible
        property int mediaSeekSeconds: appearance.runtime.appearanceDefaults.mediaSeekSeconds
        property string userOverrides: ""
    }

    readonly property var overrideKeys: parseOverrideKeys(saved.userOverrides)
    readonly property bool wallpaperSpectrumEnabled: effective("wallpaperSpectrumEnabled")
    readonly property string wallpaperResizeMode: effective("wallpaperResizeMode") === "crop" ? "crop" : "fit"
    readonly property string wallpaperTargetOutput: effective("wallpaperTargetOutput")
    readonly property bool musicReactiveEnabled: effective("musicReactiveEnabled")
    readonly property bool barVisible: effective("barVisible")
    readonly property bool frameVisible: effective("frameVisible")
    readonly property bool windowTransparencyEnabled: effective("windowTransparencyEnabled")
    readonly property bool shellGlassEnabled: effective("shellGlassEnabled")
    readonly property real windowOpacity: Math.max(0.20, Math.min(1, effective("windowOpacity")))
    readonly property real glassOpacity: Math.max(0.20, Math.min(1, effective("glassOpacity")))
    readonly property string mediaVisualizerMode: effective("mediaVisualizerMode") === "curve" ? "curve" : "bars"
    readonly property bool mediaLyricsVisible: effective("mediaLyricsVisible")
    readonly property var seekIntervals: [5, 10, 15, 30, 60]
    readonly property int mediaSeekSeconds: seekIntervals.includes(effective("mediaSeekSeconds")) ? effective("mediaSeekSeconds") : runtime.appearanceDefaults.mediaSeekSeconds

    function parseOverrideKeys(value: string): var {
        try {
            const parsed = JSON.parse(value);
            return Array.isArray(parsed) ? parsed.filter(key => typeof key === "string") : [];
        } catch (_) {
            return [];
        }
    }

    function effective(key: string): var {
        return overrideKeys.includes(key) ? saved[key] : runtime.appearanceDefaults[key];
    }

    function storeOverride(key: string, value: var): void {
        saved[key] = value;
        saved.setValue(key, value);
        if (!overrideKeys.includes(key)) {
            saved.userOverrides = JSON.stringify([...overrideKeys, key]);
            saved.setValue("userOverrides", saved.userOverrides);
        }
    }

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

    // The override list is the source of preference precedence. Existing INI
    // values are retained during migration; reset clears only their authority.
    Component.onCompleted: {
        if (saved.userOverrides !== "")
            return;
        const legacy = Object.keys(runtime.appearanceDefaults).filter(key => saved.value(key, null) !== null);
        saved.userOverrides = JSON.stringify(legacy);
        saved.setValue("userOverrides", saved.userOverrides);
        saved.sync();
        applyWindowTransparency();
        applyShellGlass();
    }

    function resetToDeclared(): void {
        saved.userOverrides = "[]";
        saved.setValue("userOverrides", "[]");
        saved.sync();
        windowOpacityApply.stop();
        applyWindowTransparency();
        applyShellGlass();
    }

    function setWallpaperTargetOutput(output: string): void {
        if (output.length === 0 || wallpaperTargetOutput === output)
            return;
        saved.wallpaperTargetOutput = output;
        storeOverride("wallpaperTargetOutput", output);
        saved.sync();
    }

    function toggleWallpaperResizeMode(): void {
        saved.wallpaperResizeMode = wallpaperResizeMode === "fit" ? "crop" : "fit";
        storeOverride("wallpaperResizeMode", saved.wallpaperResizeMode);
        saved.sync();
    }

    function toggleWallpaperSpectrum(): void {
        saved.wallpaperSpectrumEnabled = !wallpaperSpectrumEnabled;
        storeOverride("wallpaperSpectrumEnabled", saved.wallpaperSpectrumEnabled);
        saved.sync();
    }

    function toggleMusicReactive(): void {
        saved.musicReactiveEnabled = !musicReactiveEnabled;
        storeOverride("musicReactiveEnabled", saved.musicReactiveEnabled);
        saved.sync();
    }

    function toggleFrame(): void {
        saved.frameVisible = !frameVisible;
        storeOverride("frameVisible", saved.frameVisible);
        saved.sync();
    }

    function toggleBar(): void {
        saved.barVisible = !barVisible;
        storeOverride("barVisible", saved.barVisible);
        saved.sync();
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
        const next = Math.round(Math.max(0.20, Math.min(1, value)) * 100) / 100;
        if (next === windowOpacity && windowTransparencyEnabled)
            return;
        saved.windowOpacity = next;
        saved.windowTransparencyEnabled = true;
        storeOverride("windowOpacity", next);
        storeOverride("windowTransparencyEnabled", true);
        saved.sync();
        windowOpacityApply.restart();
    }

    function setGlassOpacity(value: real): void {
        const next = Math.round(Math.max(0.20, Math.min(1, value)) * 100) / 100;
        if (next === glassOpacity && shellGlassEnabled)
            return;
        const wasEnabled = shellGlassEnabled;
        saved.glassOpacity = next;
        saved.shellGlassEnabled = true;
        storeOverride("glassOpacity", next);
        storeOverride("shellGlassEnabled", true);
        saved.sync();
        // Alpha is a live QML theme binding. Only a newly enabled glass mode
        // needs Hyprland blur rules; dragging never spawns seven processes.
        if (!wasEnabled)
            applyShellGlass();
    }

    function toggleWindowTransparency(): void {
        saved.windowTransparencyEnabled = !windowTransparencyEnabled;
        storeOverride("windowTransparencyEnabled", saved.windowTransparencyEnabled);
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
        saved.shellGlassEnabled = !shellGlassEnabled;
        storeOverride("shellGlassEnabled", saved.shellGlassEnabled);
        saved.sync();
        applyShellGlass();
    }

    function adjustMediaSeek(direction: int): void {
        const current = seekIntervals.indexOf(mediaSeekSeconds);
        const index = Math.max(0, Math.min(seekIntervals.length - 1, current + direction));
        if (index === current)
            return;
        saved.mediaSeekSeconds = seekIntervals[index];
        storeOverride("mediaSeekSeconds", saved.mediaSeekSeconds);
        saved.sync();
    }

    function toggleMediaVisualizer(): void {
        saved.mediaVisualizerMode = mediaVisualizerMode === "bars" ? "curve" : "bars";
        storeOverride("mediaVisualizerMode", saved.mediaVisualizerMode);
        saved.sync();
    }

    function toggleMediaLyrics(): void {
        saved.mediaLyricsVisible = !mediaLyricsVisible;
        storeOverride("mediaLyricsVisible", saved.mediaLyricsVisible);
        saved.sync();
    }
}
