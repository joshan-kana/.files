import QtQuick
import Quickshell
import Quickshell.Hyprland

// One persistent owner for user-selected visual modes. These are preferences,
// not session activity; the running view reads them rather than holding copies.
QtObject {
    id: appearance
    required property RuntimeConfig runtime

    property PreferenceStore settings: PreferenceStore {
        id: saved
        category: "Appearance"
        defaults: appearance.runtime.appearanceDefaults
    }

    readonly property bool wallpaperSpectrumEnabled: effective("wallpaperSpectrumEnabled")
    readonly property string wallpaperResizeMode: runtime.constraints.appearance.wallpaperResizeMode.values.includes(effective("wallpaperResizeMode")) ? effective("wallpaperResizeMode") : runtime.appearanceDefaults.wallpaperResizeMode
    readonly property string wallpaperTargetOutput: effective("wallpaperTargetOutput")
    readonly property bool musicReactiveEnabled: effective("musicReactiveEnabled")
    readonly property real musicReactiveSensitivity: runtime.bounded("appearance", "musicReactiveSensitivity", effective("musicReactiveSensitivity"))
    readonly property real musicReactiveAttack: runtime.bounded("appearance", "musicReactiveAttack", effective("musicReactiveAttack"))
    readonly property real musicReactiveRelease: runtime.bounded("appearance", "musicReactiveRelease", effective("musicReactiveRelease"))
    readonly property real musicReactiveSmoothing: runtime.bounded("appearance", "musicReactiveSmoothing", effective("musicReactiveSmoothing"))
    readonly property real musicReactiveIntensity: runtime.bounded("appearance", "musicReactiveIntensity", effective("musicReactiveIntensity"))
    readonly property string musicReactiveEmphasis: runtime.constraints.appearance.musicReactiveEmphasis.values.includes(effective("musicReactiveEmphasis")) ? effective("musicReactiveEmphasis") : runtime.appearanceDefaults.musicReactiveEmphasis
    readonly property real spectrumSensitivity: runtime.bounded("appearance", "spectrumSensitivity", effective("spectrumSensitivity"))
    readonly property real spectrumAttack: runtime.bounded("appearance", "spectrumAttack", effective("spectrumAttack"))
    readonly property real spectrumRelease: runtime.bounded("appearance", "spectrumRelease", effective("spectrumRelease"))
    readonly property int wallpaperSpectrumBars: runtime.bounded("appearance", "wallpaperSpectrumBars", effective("wallpaperSpectrumBars"))
    readonly property real wallpaperSpectrumOpacity: runtime.bounded("appearance", "wallpaperSpectrumOpacity", effective("wallpaperSpectrumOpacity"))
    readonly property var reactiveParameters: [
        {
            key: "musicReactiveSensitivity",
            title: "Sensitivity",
            description: "Response to quiet audio",
            minimum: runtime.constraints.appearance.musicReactiveSensitivity.min * 100,
            maximum: runtime.constraints.appearance.musicReactiveSensitivity.max * 100,
            step: 5,
            suffix: "%"
        },
        {
            key: "musicReactiveAttack",
            title: "Attack",
            description: "Strength of beat transients",
            minimum: runtime.constraints.appearance.musicReactiveAttack.min * 100,
            maximum: runtime.constraints.appearance.musicReactiveAttack.max * 100,
            step: 5,
            suffix: "%"
        },
        {
            key: "musicReactiveRelease",
            title: "Release speed",
            description: "Higher values settle sooner",
            minimum: runtime.constraints.appearance.musicReactiveRelease.min * 100,
            maximum: runtime.constraints.appearance.musicReactiveRelease.max * 100,
            step: 5,
            suffix: "%"
        },
        {
            key: "musicReactiveSmoothing",
            title: "Smoothing",
            description: "Smooth the sustained envelope",
            minimum: runtime.constraints.appearance.musicReactiveSmoothing.min * 100,
            maximum: runtime.constraints.appearance.musicReactiveSmoothing.max * 100,
            step: 5,
            suffix: "%"
        },
        {
            key: "musicReactiveIntensity",
            title: "Tint intensity",
            description: "Strength of the shared shell tint",
            minimum: runtime.constraints.appearance.musicReactiveIntensity.min * 100,
            maximum: runtime.constraints.appearance.musicReactiveIntensity.max * 100,
            step: 5,
            suffix: "%"
        }
    ]
    readonly property var musicReactiveParameterKeys: ["musicReactiveSensitivity", "musicReactiveAttack", "musicReactiveRelease", "musicReactiveSmoothing", "musicReactiveIntensity", "musicReactiveEmphasis"]
    readonly property var reactivePresets: ({
            Subtle: [0.75, 0.8, 1.3, 0.5, 0.65, "balanced"],
            Energetic: [1.6, 1.6, 0.75, 0.2, 1.5, "bass"]
        })
    readonly property string musicReactivePreset: {
        if (musicReactiveParameterKeys.every(key => !hasOverride(key)))
            return "Default";
        for (const name of Object.keys(reactivePresets)) {
            if (musicReactiveParameterKeys.every((key, index) => {
                const value = effective(key);
                const expected = reactivePresets[name][index];
                return typeof expected === "number" ? Math.abs(value - expected) <= 0.005 : value === expected;
            }))
                return name;
        }
        return "Custom";
    }
    readonly property int barIslandHeight: runtime.bounded("appearance", "barIslandHeight", effective("barIslandHeight"))
    readonly property int frameThickness: runtime.bounded("appearance", "frameThickness", effective("frameThickness"))
    function setGeometryPreference(key: string, value: real): void {
        const bounds = ["barIslandHeight", "frameThickness"].includes(key);
        if (bounds && Number.isFinite(value)) {
            storeOverride(key, Math.round(runtime.bounded("appearance", key, value)));
        }
    }
    readonly property bool barVisible: effective("barVisible")
    readonly property bool frameVisible: effective("frameVisible")
    readonly property bool windowTransparencyEnabled: effective("windowTransparencyEnabled")
    readonly property bool shellGlassEnabled: effective("shellGlassEnabled")
    readonly property real windowOpacity: runtime.bounded("appearance", "windowOpacity", effective("windowOpacity"))
    readonly property real glassOpacity: runtime.bounded("appearance", "glassOpacity", effective("glassOpacity"))
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
    readonly property real vhsIntensity: runtime.bounded("appearance", "vhsIntensity", effective("vhsIntensity"))
    readonly property real vhsTracking: runtime.bounded("appearance", "vhsTracking", effective("vhsTracking"))
    readonly property real vhsChroma: runtime.bounded("appearance", "vhsChroma", effective("vhsChroma"))
    readonly property real vhsNoise: runtime.bounded("appearance", "vhsNoise", effective("vhsNoise"))
    readonly property real vhsScanlines: runtime.bounded("appearance", "vhsScanlines", effective("vhsScanlines"))
    readonly property real vhsSpeed: runtime.bounded("appearance", "vhsSpeed", effective("vhsSpeed"))
    readonly property real vhsDropouts: runtime.bounded("appearance", "vhsDropouts", effective("vhsDropouts"))
    function hasOverride(key: string): bool {
        return saved.has(key);
    }
    readonly property string mediaVisualizerMode: runtime.constraints.appearance.mediaVisualizerMode.values.includes(effective("mediaVisualizerMode")) ? effective("mediaVisualizerMode") : runtime.appearanceDefaults.mediaVisualizerMode
    readonly property bool mediaLyricsVisible: effective("mediaLyricsVisible")
    readonly property var seekIntervals: runtime.constraints.appearance.mediaSeekSeconds.values
    readonly property string mediaPreferredPlayer: effective("mediaPreferredPlayer")
    readonly property int mediaSeekSeconds: seekIntervals.includes(effective("mediaSeekSeconds")) ? effective("mediaSeekSeconds") : runtime.appearanceDefaults.mediaSeekSeconds

    function setMediaPreferredPlayer(identity: string): void {
        storeOverride("mediaPreferredPlayer", identity);
    }

    function resetMediaPreferredPlayer(): void {
        clearOverride("mediaPreferredPlayer");
    }

    // Scene-owned visual switches shadow saved preferences only for this session.
    property var sceneValues: ({})
    function effective(key: string): var {
        return Object.prototype.hasOwnProperty.call(sceneValues, key) ? sceneValues[key] : saved.value(key);
    }

    function setSceneValues(values: var): void {
        const before = [vhsEnabled, windowTransparencyEnabled, shellGlassEnabled, blurEnabled];
        sceneValues = values;
        if (before[0] !== vhsEnabled)
            applyVhs();
        if (before[1] !== windowTransparencyEnabled)
            applyWindowTransparency();
        if (before[2] !== shellGlassEnabled)
            applyShellGlass();
        if (before[3] !== blurEnabled)
            applyBlurSize();
    }

    function storeOverride(key: string, value: var): void {
        if (Object.prototype.hasOwnProperty.call(sceneValues, key))
            sceneValues = Object.assign({}, sceneValues, {
                [key]: value
            });
        else
            saved.set(key, value);
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

    Component.onCompleted: {
        const old = {};
        const marker = saved.legacy("userOverrides", "");
        let keys = Object.keys(runtime.appearanceDefaults);
        if (marker) {
            try {
                const parsed = JSON.parse(marker);
                keys = Array.isArray(parsed) ? parsed : [];
            } catch (_) {
                keys = [];
            }
        }
        for (const key of keys) {
            if (Object.prototype.hasOwnProperty.call(runtime.appearanceDefaults, key))
                old[key] = saved.legacy(key, runtime.appearanceDefaults[key]);
        }
        saved.initialize(old);
        applyVhs();
        applyWindowTransparency();
        applyShellGlass();
        applyBlurSize();
    }

    function resetToDeclared(): void {
        sceneValues = {};
        saved.resetAll();
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
        storeOverride("wallpaperTargetOutput", output);
    }

    function toggleWallpaperResizeMode(): void {
        storeOverride("wallpaperResizeMode", wallpaperResizeMode === "fit" ? "crop" : "fit");
    }

    function toggleWallpaperSpectrum(): void {
        storeOverride("wallpaperSpectrumEnabled", !wallpaperSpectrumEnabled);
    }

    function toggleMusicReactive(): void {
        storeOverride("musicReactiveEnabled", !musicReactiveEnabled);
    }

    function setVisualParameter(key: string, value: real): void {
        if (!reactiveParameters.some(parameter => parameter.key === key) && !["spectrumSensitivity", "spectrumAttack", "spectrumRelease", "wallpaperSpectrumOpacity"].includes(key) || !isFinite(value))
            return;
        const next = Math.round(runtime.bounded("appearance", key, value) * 100) / 100;
        if (next === effective(key))
            return;
        storeOverride(key, next);
    }

    function setReactiveEmphasis(value: string): void {
        if (!runtime.constraints.appearance.musicReactiveEmphasis.values.includes(value) || musicReactiveEmphasis === value)
            return;
        storeOverride("musicReactiveEmphasis", value);
    }

    function setSpectrumBars(value: int): void {
        storeOverride("wallpaperSpectrumBars", runtime.bounded("appearance", "wallpaperSpectrumBars", value));
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
        const values = reactivePresets[name];
        if (!values)
            return;
        saved.setMany(Object.fromEntries(musicReactiveParameterKeys.map((key, index) => [key, values[index]])));
    }

    function resetSpectrumTuning(): void {
        clearOverride("spectrumSensitivity");
        clearOverride("spectrumAttack");
        clearOverride("spectrumRelease");
        clearOverride("wallpaperSpectrumOpacity");
        clearOverride("wallpaperSpectrumBars");
    }

    function toggleFrame(): void {
        storeOverride("frameVisible", !frameVisible);
    }

    function toggleBar(): void {
        storeOverride("barVisible", !barVisible);
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
            saved.setMany(Object.fromEntries(vhsParameterKeys.map((key, index) => [key, values[index]])));
        }

        vhsApply.restart();
    }

    function resetVhs(): void {
        clearOverride("vhsEnabled");
        applyVhsPreset("Default");
    }

    function resetVhsParameter(key: string): void {
        if (!vhsParameterKeys.includes(key))
            return;
        clearOverride(key);
        vhsApply.restart();
    }

    function toggleVhs(): void {
        storeOverride("vhsEnabled", !vhsEnabled);

        vhsApply.stop();
        applyVhs();
    }

    function setVhsParameter(key: string, value: real): void {
        if (!["vhsTracking", "vhsChroma", "vhsNoise", "vhsScanlines", "vhsSpeed", "vhsDropouts"].includes(key))
            return;
        const next = Math.round(runtime.bounded("appearance", key, value) * 100) / 100;
        if (next === effective(key) && vhsEnabled)
            return;
        storeOverride(key, next);
        storeOverride("vhsEnabled", true);

        vhsApply.restart();
    }

    function setVhsIntensity(value: real): void {
        const next = Math.round(runtime.bounded("appearance", "vhsIntensity", value) * 100) / 100;
        if (next === vhsIntensity && vhsEnabled)
            return;
        storeOverride("vhsIntensity", next);
        storeOverride("vhsEnabled", true);

        // Reload after the slider settles to avoid shader recompilation every pointer event.
        vhsApply.restart();
    }

    function applyBlurSize(): void {
        if (runtime.hyprctl.length === 0)
            return;
        Quickshell.execDetached([runtime.hyprctl, "eval", "hl.config({ decoration = { blur = { enabled = " + (blurEnabled ? "true" : "false") + ", size = " + blurSize + " } } })"]);
    }

    function clearOverride(key: string): void {
        if (Object.prototype.hasOwnProperty.call(sceneValues, key))
            sceneValues = Object.assign({}, sceneValues, {
                [key]: runtime.appearanceDefaults[key]
            });
        else
            saved.reset(key);
    }

    function toggleBlur(): void {
        const next = !blurEnabled;
        storeOverride("blurEnabled", next);

        applyBlurSize();
    }

    function setBlurSize(value: real): void {
        const next = Math.round(Math.max(5, Math.min(25, value)));
        if (next === blurSize)
            return;
        storeOverride("blurSize", next);

        blurSizeApply.restart();
    }

    function applyWindowTransparency(): void {
        if (runtime.hyprctl.length === 0)
            return;
        const opacity = (windowTransparencyEnabled ? windowOpacity : 1).toFixed(2);
        Quickshell.execDetached([runtime.hyprctl, "eval", "hl.config({ decoration = { active_opacity = " + opacity + ", inactive_opacity = " + opacity + " } })"]);
    }

    function setWindowOpacity(value: real): void {
        const next = Math.round(runtime.bounded("appearance", "windowOpacity", value) * 100) / 100;
        if (next === windowOpacity && windowTransparencyEnabled)
            return;
        storeOverride("windowOpacity", next);
        storeOverride("windowTransparencyEnabled", true);

        windowOpacityApply.restart();
    }

    function setGlassOpacity(value: real): void {
        const next = Math.round(runtime.bounded("appearance", "glassOpacity", value) * 100) / 100;
        if (next === glassOpacity && shellGlassEnabled)
            return;
        const wasEnabled = shellGlassEnabled;
        storeOverride("glassOpacity", next);
        storeOverride("shellGlassEnabled", true);

        // Alpha is a live QML theme binding. Only a newly enabled glass mode
        // needs Hyprland blur rules; dragging never spawns seven processes.
        if (!wasEnabled)
            applyShellGlass();
    }

    function toggleWindowTransparency(): void {
        storeOverride("windowTransparencyEnabled", !windowTransparencyEnabled);

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
        storeOverride("shellGlassEnabled", !shellGlassEnabled);

        applyShellGlass();
    }

    function adjustMediaSeek(direction: int): void {
        const current = seekIntervals.indexOf(mediaSeekSeconds);
        const index = Math.max(0, Math.min(seekIntervals.length - 1, current + direction));
        if (index === current)
            return;
        storeOverride("mediaSeekSeconds", seekIntervals[index]);
    }

    function toggleMediaVisualizer(): void {
        storeOverride("mediaVisualizerMode", mediaVisualizerMode === "bars" ? "curve" : "bars");
    }

    function toggleMediaLyrics(): void {
        storeOverride("mediaLyricsVisible", !mediaLyricsVisible);
    }
}
