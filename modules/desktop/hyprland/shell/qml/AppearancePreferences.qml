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
        location: "file://" + (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/desktop-shell/preferences.ini"
        category: "Appearance"
        property bool wallpaperSpectrumEnabled: appearance.runtime.appearanceDefaults.wallpaperSpectrumEnabled
        property string wallpaperResizeMode: appearance.runtime.appearanceDefaults.wallpaperResizeMode
        property string wallpaperTargetOutput: appearance.runtime.appearanceDefaults.wallpaperTargetOutput
        property bool musicReactiveEnabled: appearance.runtime.appearanceDefaults.musicReactiveEnabled
        property real musicReactiveSensitivity: appearance.runtime.appearanceDefaults.musicReactiveSensitivity
        property real musicReactiveAttack: appearance.runtime.appearanceDefaults.musicReactiveAttack
        property real musicReactiveRelease: appearance.runtime.appearanceDefaults.musicReactiveRelease
        property real musicReactiveSmoothing: appearance.runtime.appearanceDefaults.musicReactiveSmoothing
        property real musicReactiveIntensity: appearance.runtime.appearanceDefaults.musicReactiveIntensity
        property string musicReactiveEmphasis: appearance.runtime.appearanceDefaults.musicReactiveEmphasis
        property real spectrumSensitivity: appearance.runtime.appearanceDefaults.spectrumSensitivity
        property real spectrumAttack: appearance.runtime.appearanceDefaults.spectrumAttack
        property real spectrumRelease: appearance.runtime.appearanceDefaults.spectrumRelease
        property int wallpaperSpectrumBars: appearance.runtime.appearanceDefaults.wallpaperSpectrumBars
        property real wallpaperSpectrumOpacity: appearance.runtime.appearanceDefaults.wallpaperSpectrumOpacity
        property int barIslandHeight: appearance.runtime.appearanceDefaults.barIslandHeight
        property int frameThickness: appearance.runtime.appearanceDefaults.frameThickness
        property bool barVisible: appearance.runtime.appearanceDefaults.barVisible
        property bool frameVisible: appearance.runtime.appearanceDefaults.frameVisible
        property bool windowTransparencyEnabled: appearance.runtime.appearanceDefaults.windowTransparencyEnabled
        property bool shellGlassEnabled: appearance.runtime.appearanceDefaults.shellGlassEnabled
        property real windowOpacity: appearance.runtime.appearanceDefaults.windowOpacity
        property real glassOpacity: appearance.runtime.appearanceDefaults.glassOpacity
        property bool blurEnabled: appearance.runtime.appearanceDefaults.blurEnabled
        property int blurSize: appearance.runtime.appearanceDefaults.blurSize
        property bool vhsEnabled: appearance.runtime.appearanceDefaults.vhsEnabled
        property real vhsIntensity: appearance.runtime.appearanceDefaults.vhsIntensity
        property real vhsTracking: appearance.runtime.appearanceDefaults.vhsTracking
        property real vhsChroma: appearance.runtime.appearanceDefaults.vhsChroma
        property real vhsNoise: appearance.runtime.appearanceDefaults.vhsNoise
        property real vhsScanlines: appearance.runtime.appearanceDefaults.vhsScanlines
        property real vhsSpeed: appearance.runtime.appearanceDefaults.vhsSpeed
        property real vhsDropouts: appearance.runtime.appearanceDefaults.vhsDropouts
        property string mediaVisualizerMode: appearance.runtime.appearanceDefaults.mediaVisualizerMode
        property bool mediaLyricsVisible: appearance.runtime.appearanceDefaults.mediaLyricsVisible
        property string mediaPreferredPlayer: appearance.runtime.appearanceDefaults.mediaPreferredPlayer
        property int mediaSeekSeconds: appearance.runtime.appearanceDefaults.mediaSeekSeconds
        property string userOverrides: ""
    }

    readonly property var overrideKeys: parseOverrideKeys(saved.userOverrides)
    readonly property bool wallpaperSpectrumEnabled: effective("wallpaperSpectrumEnabled")
    readonly property string wallpaperResizeMode: effective("wallpaperResizeMode") === "crop" ? "crop" : "fit"
    readonly property string wallpaperTargetOutput: effective("wallpaperTargetOutput")
    readonly property bool musicReactiveEnabled: effective("musicReactiveEnabled")
    readonly property real musicReactiveSensitivity: Math.max(0.4, Math.min(3.0, effective("musicReactiveSensitivity")))
    readonly property real musicReactiveAttack: Math.max(0.5, Math.min(2.5, effective("musicReactiveAttack")))
    readonly property real musicReactiveRelease: Math.max(0.4, Math.min(2.5, effective("musicReactiveRelease")))
    readonly property real musicReactiveSmoothing: Math.max(0, Math.min(0.9, effective("musicReactiveSmoothing")))
    readonly property real musicReactiveIntensity: Math.max(0.25, Math.min(2.0, effective("musicReactiveIntensity")))
    readonly property string musicReactiveEmphasis: ["balanced", "bass", "mid", "treble"].includes(effective("musicReactiveEmphasis")) ? effective("musicReactiveEmphasis") : "balanced"
    readonly property real spectrumSensitivity: Math.max(0.4, Math.min(3.0, effective("spectrumSensitivity")))
    readonly property real spectrumAttack: Math.max(0.25, Math.min(2.5, effective("spectrumAttack")))
    readonly property real spectrumRelease: Math.max(0.25, Math.min(2.5, effective("spectrumRelease")))
    readonly property int wallpaperSpectrumBars: Math.max(24, Math.min(96, effective("wallpaperSpectrumBars")))
    readonly property real wallpaperSpectrumOpacity: Math.max(0.2, Math.min(1.0, effective("wallpaperSpectrumOpacity")))
    readonly property var reactiveParameters: [
        {
            key: "musicReactiveSensitivity",
            title: "Sensitivity",
            description: "Response to quiet audio",
            minimum: 40,
            maximum: 300,
            step: 5,
            suffix: "%"
        },
        {
            key: "musicReactiveAttack",
            title: "Attack",
            description: "Strength of beat transients",
            minimum: 50,
            maximum: 250,
            step: 5,
            suffix: "%"
        },
        {
            key: "musicReactiveRelease",
            title: "Release speed",
            description: "Higher values settle sooner",
            minimum: 40,
            maximum: 250,
            step: 5,
            suffix: "%"
        },
        {
            key: "musicReactiveSmoothing",
            title: "Smoothing",
            description: "Smooth the sustained envelope",
            minimum: 0,
            maximum: 90,
            step: 5,
            suffix: "%"
        },
        {
            key: "musicReactiveIntensity",
            title: "Tint intensity",
            description: "Strength of the shared shell tint",
            minimum: 25,
            maximum: 200,
            step: 5,
            suffix: "%"
        }
    ]
    readonly property var musicReactiveParameterKeys: ["musicReactiveSensitivity", "musicReactiveAttack", "musicReactiveRelease", "musicReactiveSmoothing", "musicReactiveIntensity", "musicReactiveEmphasis"]
    readonly property string musicReactivePreset: {
        if (musicReactiveParameterKeys.every(key => !hasOverride(key)))
            return "Default";
        if (Math.abs(musicReactiveSensitivity - 0.75) <= 0.005 && Math.abs(musicReactiveAttack - 0.8) <= 0.005 && Math.abs(musicReactiveRelease - 1.3) <= 0.005 && Math.abs(musicReactiveSmoothing - 0.5) <= 0.005 && Math.abs(musicReactiveIntensity - 0.65) <= 0.005 && musicReactiveEmphasis === "balanced")
            return "Subtle";
        if (Math.abs(musicReactiveSensitivity - 1.6) <= 0.005 && Math.abs(musicReactiveAttack - 1.6) <= 0.005 && Math.abs(musicReactiveRelease - 0.75) <= 0.005 && Math.abs(musicReactiveSmoothing - 0.2) <= 0.005 && Math.abs(musicReactiveIntensity - 1.5) <= 0.005 && musicReactiveEmphasis === "bass")
            return "Energetic";
        return "Custom";
    }
    readonly property int barIslandHeight: Math.max(44, Math.min(60, effective("barIslandHeight")))
    readonly property int frameThickness: Math.max(18, Math.min(36, effective("frameThickness")))
    function setGeometryPreference(key: string, value: real): void {
        const bounds = key === "barIslandHeight" ? [44, 60] : key === "frameThickness" ? [18, 36] : null;
        if (bounds && Number.isFinite(value)) {
            storeOverride(key, Math.round(Math.max(bounds[0], Math.min(bounds[1], value))));
            saved.sync();
        }
    }
    readonly property bool barVisible: effective("barVisible")
    readonly property bool frameVisible: effective("frameVisible")
    readonly property bool windowTransparencyEnabled: effective("windowTransparencyEnabled")
    readonly property bool shellGlassEnabled: effective("shellGlassEnabled")
    readonly property real windowOpacity: Math.max(0.20, Math.min(1, effective("windowOpacity")))
    readonly property real glassOpacity: Math.max(0.20, Math.min(1, effective("glassOpacity")))
    readonly property bool blurEnabled: effective("blurEnabled")
    readonly property int blurSize: Math.max(5, Math.min(25, effective("blurSize")))
    readonly property var vhsParameterKeys: ["vhsIntensity", "vhsTracking", "vhsChroma", "vhsNoise", "vhsScanlines", "vhsSpeed", "vhsDropouts"]
    readonly property var vhsPresets: ({
            Subtle: [0.25, 0.15, 0.25, 0.10, 0.15, 0.8, 0.0],
            Analog: [0.55, 0.45, 0.55, 0.3, 0.4, 1.0, 0.1],
            Degraded: [0.85, 0.8, 0.8, 0.65, 0.7, 1.3, 0.55]
        })
    readonly property string vhsPreset: {
        if (vhsParameterKeys.every(key => !hasOverride(key)))
            return "Default";
        for (const name of Object.keys(vhsPresets)) {
            if (vhsParameterKeys.every((key, index) => Math.abs(effective(key) - vhsPresets[name][index]) <= 0.005))
                return name;
        }
        return "Custom";
    }
    readonly property bool vhsEnabled: effective("vhsEnabled")
    readonly property real vhsIntensity: Math.max(0, Math.min(1, effective("vhsIntensity")))
    readonly property real vhsTracking: Math.max(0, Math.min(1, effective("vhsTracking")))
    readonly property real vhsChroma: Math.max(0, Math.min(1, effective("vhsChroma")))
    readonly property real vhsNoise: Math.max(0, Math.min(1, effective("vhsNoise")))
    readonly property real vhsScanlines: Math.max(0, Math.min(1, effective("vhsScanlines")))
    readonly property real vhsSpeed: Math.max(0.25, Math.min(2.5, effective("vhsSpeed")))
    readonly property real vhsDropouts: Math.max(0, Math.min(1, effective("vhsDropouts")))
    function hasOverride(key: string): bool {
        return overrideKeys.includes(key);
    }
    readonly property string mediaVisualizerMode: effective("mediaVisualizerMode") === "curve" ? "curve" : "bars"
    readonly property bool mediaLyricsVisible: effective("mediaLyricsVisible")
    readonly property var seekIntervals: [5, 10, 15, 30, 60]
    readonly property string mediaPreferredPlayer: effective("mediaPreferredPlayer")
    readonly property int mediaSeekSeconds: seekIntervals.includes(effective("mediaSeekSeconds")) ? effective("mediaSeekSeconds") : runtime.appearanceDefaults.mediaSeekSeconds

    function setMediaPreferredPlayer(identity: string): void {
        storeOverride("mediaPreferredPlayer", identity);
        saved.sync();
    }

    function resetMediaPreferredPlayer(): void {
        clearOverride("mediaPreferredPlayer");
    }

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
    // Connected bar islands use the frame's existing glass backdrop.
    readonly property bool barGlassExposed: barVisible && !frameGlassExposed
    property bool expansionGlassExposed: false
    property bool modalGlassExposed: false
    property bool notificationGlassExposed: false
    property bool osdGlassExposed: false
    property bool resizeGlassExposed: false

    // Connected islands borrow the frame backdrop. Detached bar islands
    // have their own blur, independently of window transparency.
    onBarGlassExposedChanged: applyGlassRule("desktop-shell-shell-glass", "^desktop-shell-bar$", barGlassExposed)
    onFrameGlassExposedChanged: applyGlassRule("desktop-shell-shell-glass-frame", "^desktop-shell-frame$", frameGlassExposed)
    onExpansionGlassExposedChanged: applyGlassRule("desktop-shell-shell-glass-expansion", "^desktop-shell-expansion$", expansionGlassExposed)
    onModalGlassExposedChanged: applyGlassRule("desktop-shell-shell-glass-modal", "^desktop-shell-modal$", modalGlassExposed)
    onNotificationGlassExposedChanged: applyGlassRule("desktop-shell-shell-glass-notification", "^desktop-shell-notification-popup$", notificationGlassExposed)
    onOsdGlassExposedChanged: applyGlassRule("desktop-shell-shell-glass-osd", "^desktop-shell-osd$", osdGlassExposed)
    onResizeGlassExposedChanged: applyGlassRule("desktop-shell-shell-glass-resize", "^desktop-shell-resize-controls$", resizeGlassExposed)

    // The override list is the source of preference precedence. Existing INI
    // values are retained during migration; reset clears only their authority.
    Component.onCompleted: {
        applyVhs();
        if (saved.userOverrides !== "")
            return;
        const legacy = Object.keys(runtime.appearanceDefaults).filter(key => key !== "objectName" && saved.value(key, null) !== null);
        saved.userOverrides = JSON.stringify(legacy);
        saved.setValue("userOverrides", saved.userOverrides);
        saved.sync();
        applyWindowTransparency();
        applyShellGlass();
        applyBlurSize();
    }

    function resetToDeclared(): void {
        saved.userOverrides = "[]";
        saved.setValue("userOverrides", "[]");
        saved.sync();
        windowOpacityApply.stop();
        blurSizeApply.stop();
        vhsApply.stop();
        applyVhs();
        applyWindowTransparency();
        applyShellGlass();
        applyBlurSize();
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

    function setVisualParameter(key: string, value: real): void {
        const bounds = {
            musicReactiveSensitivity: [0.4, 3.0],
            musicReactiveAttack: [0.5, 2.5],
            musicReactiveRelease: [0.4, 2.5],
            musicReactiveSmoothing: [0.0, 0.9],
            musicReactiveIntensity: [0.25, 2.0],
            spectrumSensitivity: [0.4, 3.0],
            spectrumAttack: [0.25, 2.5],
            spectrumRelease: [0.25, 2.5],
            wallpaperSpectrumOpacity: [0.2, 1.0]
        };
        const range = bounds[key];
        if (!range || !isFinite(value))
            return;
        const next = Math.round(Math.max(range[0], Math.min(range[1], value)) * 100) / 100;
        if (next === effective(key))
            return;
        storeOverride(key, next);
        saved.sync();
    }

    function setReactiveEmphasis(value: string): void {
        if (!["balanced", "bass", "mid", "treble"].includes(value) || musicReactiveEmphasis === value)
            return;
        storeOverride("musicReactiveEmphasis", value);
        saved.sync();
    }

    function setSpectrumBars(value: int): void {
        storeOverride("wallpaperSpectrumBars", Math.max(24, Math.min(96, value)));
        saved.sync();
    }

    function resetReactiveTuning(): void {
        for (const key of musicReactiveParameterKeys)
            clearOverride(key);
    }

    function applyReactivePreset(name: string): void {
        if (name === "Default") {
            resetReactiveTuning();
            return;
        }
        const presets = {
            Subtle: [0.75, 0.8, 1.3, 0.5, 0.65, "balanced"],
            Energetic: [1.6, 1.6, 0.75, 0.2, 1.5, "bass"]
        };
        const values = presets[name];
        if (!values)
            return;
        for (let i = 0; i < musicReactiveParameterKeys.length; ++i)
            storeOverride(musicReactiveParameterKeys[i], values[i]);
        saved.sync();
    }

    function resetSpectrumTuning(): void {
        clearOverride("spectrumSensitivity");
        clearOverride("spectrumAttack");
        clearOverride("spectrumRelease");
        clearOverride("wallpaperSpectrumOpacity");
        clearOverride("wallpaperSpectrumBars");
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
        function onVhsControlChanged(): void {
            appearance.applyVhs();
        }
        function onHyprctlChanged(): void {
            appearance.applyWindowTransparency();
            appearance.applyShellGlass();
            appearance.applyBlurSize();
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
                appearance.applyVhs();
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

    property Timer blurSizeApply: Timer {
        interval: 75
        repeat: false
        onTriggered: appearance.applyBlurSize()
    }

    property Timer vhsApply: Timer {
        interval: 180
        repeat: false
        onTriggered: appearance.applyVhs()
    }

    function applyVhs(): void {
        if (runtime.vhsControl.length === 0)
            return;
        Quickshell.execDetached([runtime.vhsControl, vhsEnabled ? "on" : "off", String(Math.round(vhsIntensity * 100)), String(Math.round(vhsTracking * 100)), String(Math.round(vhsChroma * 100)), String(Math.round(vhsNoise * 100)), String(Math.round(vhsScanlines * 100)), String(Math.round(vhsSpeed * 100)), String(Math.round(vhsDropouts * 100))]);
    }

    // A preset changes only VHS parameters; it does not toggle the effect
    // or modify any other appearance preference.
    function applyVhsPreset(name: string): void {
        if (name === "Default") {
            for (const key of vhsParameterKeys)
                clearOverride(key);
        } else {
            const values = vhsPresets[name];
            if (!values)
                return;
            for (let index = 0; index < vhsParameterKeys.length; ++index)
                storeOverride(vhsParameterKeys[index], values[index]);
        }
        saved.sync();
        vhsApply.restart();
    }

    function resetVhsParameter(key: string): void {
        if (!vhsParameterKeys.includes(key))
            return;
        clearOverride(key);
        vhsApply.restart();
    }

    function toggleVhs(): void {
        saved.vhsEnabled = !vhsEnabled;
        storeOverride("vhsEnabled", saved.vhsEnabled);
        saved.sync();
        vhsApply.stop();
        applyVhs();
    }

    function setVhsParameter(key: string, value: real): void {
        if (!["vhsTracking", "vhsChroma", "vhsNoise", "vhsScanlines", "vhsSpeed", "vhsDropouts"].includes(key))
            return;
        const lower = key === "vhsSpeed" ? 0.25 : 0;
        const upper = key === "vhsSpeed" ? 2.5 : 1;
        const next = Math.round(Math.max(lower, Math.min(upper, value)) * 100) / 100;
        if (next === effective(key) && vhsEnabled)
            return;
        storeOverride(key, next);
        storeOverride("vhsEnabled", true);
        saved.sync();
        vhsApply.restart();
    }

    function setVhsIntensity(value: real): void {
        const next = Math.round(Math.max(0, Math.min(1, value)) * 100) / 100;
        if (next === vhsIntensity && vhsEnabled)
            return;
        saved.vhsIntensity = next;
        saved.vhsEnabled = true;
        storeOverride("vhsIntensity", next);
        storeOverride("vhsEnabled", true);
        saved.sync();
        // Reload after the slider settles to avoid shader recompilation every pointer event.
        vhsApply.restart();
    }

    function applyBlurSize(): void {
        if (runtime.hyprctl.length === 0)
            return;
        Quickshell.execDetached([runtime.hyprctl, "eval", "hl.config({ decoration = { blur = { enabled = " + (blurEnabled ? "true" : "false") + ", size = " + blurSize + " } } })"]);
    }

    function clearOverride(key: string): void {
        if (!overrideKeys.includes(key))
            return;
        const remaining = overrideKeys.filter(value => value !== key);
        saved.userOverrides = JSON.stringify(remaining);
        saved.setValue("userOverrides", saved.userOverrides);
        saved.sync();
    }

    function toggleBlur(): void {
        const next = !blurEnabled;
        storeOverride("blurEnabled", next);
        saved.sync();
        applyBlurSize();
    }

    function setBlurSize(value: real): void {
        const next = Math.round(Math.max(5, Math.min(25, value)));
        if (next === blurSize)
            return;
        saved.blurSize = next;
        storeOverride("blurSize", next);
        saved.sync();
        blurSizeApply.restart();
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
        applyGlassRule("desktop-shell-shell-glass", "^desktop-shell-bar$", barGlassExposed);
        applyGlassRule("desktop-shell-shell-glass-frame", "^desktop-shell-frame$", frameGlassExposed);
        applyGlassRule("desktop-shell-shell-glass-expansion", "^desktop-shell-expansion$", expansionGlassExposed);
        applyGlassRule("desktop-shell-shell-glass-modal", "^desktop-shell-modal$", modalGlassExposed);
        applyGlassRule("desktop-shell-shell-glass-notification", "^desktop-shell-notification-popup$", notificationGlassExposed);
        applyGlassRule("desktop-shell-shell-glass-osd", "^desktop-shell-osd$", osdGlassExposed);
        applyGlassRule("desktop-shell-shell-glass-resize", "^desktop-shell-resize-controls$", resizeGlassExposed);
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
