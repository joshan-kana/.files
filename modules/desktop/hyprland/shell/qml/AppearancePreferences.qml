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
        constraints: appearance.runtime.constraints.appearance
    }

    readonly property bool wallpaperSpectrumEnabled: effective("wallpaperSpectrumEnabled")
    readonly property string wallpaperResizeMode: effective("wallpaperResizeMode")
    readonly property string wallpaperTargetOutput: effective("wallpaperTargetOutput")
    readonly property bool musicReactiveEnabled: effective("musicReactiveEnabled")
    readonly property real musicReactiveSensitivity: effective("musicReactiveSensitivity")
    readonly property real musicReactiveAttack: effective("musicReactiveAttack")
    readonly property real musicReactiveRelease: effective("musicReactiveRelease")
    readonly property real musicReactiveSmoothing: effective("musicReactiveSmoothing")
    readonly property real musicReactiveIntensity: effective("musicReactiveIntensity")
    readonly property string musicReactiveEmphasis: effective("musicReactiveEmphasis")
    readonly property real spectrumSensitivity: effective("spectrumSensitivity")
    readonly property real spectrumAttack: effective("spectrumAttack")
    readonly property real spectrumRelease: effective("spectrumRelease")
    readonly property real spectrumDensity: effective("spectrumDensity")
    readonly property real spectrumOpacity: effective("spectrumOpacity")
    readonly property var spectrumSurfaces: [
        {
            key: "wallpaperVisualizerMode",
            title: "Wallpaper"
        },
        {
            key: "islandVisualizerMode",
            title: "Media island"
        },
        {
            key: "controlsVisualizerMode",
            title: "Controls media"
        },
        {
            key: "mediaVisualizerMode",
            title: "Now Playing"
        }
    ]
    readonly property var spectrumParameters: [
        {
            key: "spectrumSensitivity",
            title: "Sensitivity",
            description: "Amplitude of every spectrum",
            step: 5
        },
        {
            key: "spectrumAttack",
            title: "Attack speed",
            description: "Rise speed of every spectrum",
            step: 5
        },
        {
            key: "spectrumRelease",
            title: "Release speed",
            description: "Fall speed of every spectrum",
            step: 5
        },
        {
            key: "spectrumDensity",
            title: "Density",
            description: "Resolution relative to available space",
            step: 5
        },
        {
            key: "spectrumOpacity",
            title: "Opacity multiplier",
            description: "Shared strength of every spectrum",
            step: 5
        }
    ].map(entry => Object.assign({}, entry, {
            minimum: runtime.constraints.appearance[entry.key].min * 100,
            maximum: runtime.constraints.appearance[entry.key].max * 100,
            suffix: "%"
        }))
    function spectrumMode(key: string): string {
        return effective(key);
    }
    function toggleSpectrumMode(key: string): void {
        if (!spectrumSurfaces.some(surface => surface.key === key))
            return;
        const values = runtime.constraints.appearance[key].values;
        storeOverride(key, values[(values.indexOf(spectrumMode(key)) + 1) % values.length]);
    }
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
    readonly property var musicReactiveParameterKeys: reactiveParameters.map(parameter => parameter.key).concat(["musicReactiveEmphasis"])
    readonly property var reactivePresets: ({
            Subtle: {
                musicReactiveSensitivity: 0.75,
                musicReactiveAttack: 0.8,
                musicReactiveRelease: 1.3,
                musicReactiveSmoothing: 0.5,
                musicReactiveIntensity: 0.65,
                musicReactiveEmphasis: "balanced"
            },
            Default: null,
            Energetic: {
                musicReactiveSensitivity: 1.6,
                musicReactiveAttack: 1.6,
                musicReactiveRelease: 0.75,
                musicReactiveSmoothing: 0.2,
                musicReactiveIntensity: 1.5,
                musicReactiveEmphasis: "bass"
            }
        })
    readonly property var reactivePresetNames: presetNames(reactivePresets, musicReactiveParameterKeys)
    readonly property string musicReactivePreset: selectedPreset(reactivePresets, musicReactiveParameterKeys)
    readonly property int barIslandHeight: effective("barIslandHeight")
    readonly property int frameThickness: effective("frameThickness")
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
    readonly property real windowOpacity: effective("windowOpacity")
    readonly property real glassOpacity: effective("glassOpacity")
    readonly property bool blurEnabled: effective("blurEnabled")
    readonly property int blurSize: effective("blurSize")
    readonly property var vhsParameterKeys: ["vhsIntensity", "vhsTracking", "vhsChroma", "vhsNoise", "vhsScanlines", "vhsSpeed", "vhsDropouts"]
    readonly property var vhsPresets: ({
            Subtle: {
                vhsIntensity: 0.25,
                vhsTracking: 0.15,
                vhsChroma: 0.25,
                vhsNoise: 0.10,
                vhsScanlines: 0.15,
                vhsSpeed: 0.8,
                vhsDropouts: 0.0
            },
            Analog: {
                vhsIntensity: 0.55,
                vhsTracking: 0.45,
                vhsChroma: 0.55,
                vhsNoise: 0.3,
                vhsScanlines: 0.4,
                vhsSpeed: 1.0,
                vhsDropouts: 0.1
            },
            Degraded: {
                vhsIntensity: 0.85,
                vhsTracking: 0.8,
                vhsChroma: 0.8,
                vhsNoise: 0.65,
                vhsScanlines: 0.7,
                vhsSpeed: 1.3,
                vhsDropouts: 0.55
            },
            Default: null
        })
    readonly property var vhsPresetNames: presetNames(vhsPresets, vhsParameterKeys)
    readonly property string vhsPreset: selectedPreset(vhsPresets, vhsParameterKeys)
    readonly property bool vhsEnabled: effective("vhsEnabled")
    readonly property real vhsIntensity: effective("vhsIntensity")
    readonly property real vhsTracking: effective("vhsTracking")
    readonly property real vhsChroma: effective("vhsChroma")
    readonly property real vhsNoise: effective("vhsNoise")
    readonly property real vhsScanlines: effective("vhsScanlines")
    readonly property real vhsSpeed: effective("vhsSpeed")
    readonly property real vhsDropouts: effective("vhsDropouts")
    function hasOverride(key: string): bool {
        return saved.has(key);
    }
    readonly property string mediaVisualizerMode: effective("mediaVisualizerMode")
    readonly property bool mediaLyricsVisible: effective("mediaLyricsVisible")
    readonly property var seekIntervals: runtime.constraints.appearance.mediaSeekSeconds.values
    readonly property string mediaPreferredPlayer: effective("mediaPreferredPlayer")
    readonly property int mediaSeekSeconds: effective("mediaSeekSeconds")

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

    function migrateSpectrumOverrides(values: var): var {
        const next = Object.assign({}, values);
        // Historical wallpaper baselines were 64 bars and 80% opacity.
        const density = next.wallpaperSpectrumBars / 64;
        const opacity = next.wallpaperSpectrumOpacity / 0.8;
        if (!saved.valid("spectrumDensity", next.spectrumDensity) && typeof next.wallpaperSpectrumBars === "number" && saved.valid("spectrumDensity", density))
            next.spectrumDensity = density;
        if (!saved.valid("spectrumOpacity", next.spectrumOpacity) && typeof next.wallpaperSpectrumOpacity === "number" && saved.valid("spectrumOpacity", opacity))
            next.spectrumOpacity = opacity;
        delete next.wallpaperSpectrumBars;
        delete next.wallpaperSpectrumOpacity;
        delete next.previewVisualizerMode;
        return next;
    }

    Component.onCompleted: {
        if (saved.uninitialized) {
            const old = {};
            const marker = saved.legacy("userOverrides", "");
            let keys = Object.keys(runtime.appearanceDefaults).concat(["wallpaperSpectrumBars", "wallpaperSpectrumOpacity"]);
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
                else if (key === "wallpaperSpectrumBars" || key === "wallpaperSpectrumOpacity")
                    old[key] = saved.legacy(key, 0);
            }
            saved.initialize(migrateSpectrumOverrides(old));
        } else if (["wallpaperSpectrumBars", "wallpaperSpectrumOpacity", "previewVisualizerMode"].some(key => Object.prototype.hasOwnProperty.call(saved.overrides, key))) {
            saved.write(migrateSpectrumOverrides(saved.overrides));
        }
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
        const values = runtime.constraints.appearance.wallpaperResizeMode.values;
        storeOverride("wallpaperResizeMode", values[(values.indexOf(wallpaperResizeMode) + 1) % values.length]);
    }

    function toggleWallpaperSpectrum(): void {
        storeOverride("wallpaperSpectrumEnabled", !wallpaperSpectrumEnabled);
    }

    function toggleMusicReactive(): void {
        storeOverride("musicReactiveEnabled", !musicReactiveEnabled);
    }

    function setVisualParameter(key: string, value: real): void {
        if (!reactiveParameters.some(parameter => parameter.key === key) && !spectrumParameters.some(parameter => parameter.key === key) || !isFinite(value))
            return;
        const precision = key === "spectrumDensity" ? 1000 : 100;
        const next = runtime.bounded("appearance", key, Math.round(value * precision) / precision);
        if (next === effective(key))
            return;
        storeOverride(key, next);
    }

    function setReactiveEmphasis(value: string): void {
        if (!runtime.constraints.appearance.musicReactiveEmphasis.values.includes(value) || musicReactiveEmphasis === value)
            return;
        storeOverride("musicReactiveEmphasis", value);
    }

    function resetReactiveTuning(): void {
        saved.resetMany(musicReactiveParameterKeys);
    }

    function presetNames(presets: var, keys: var): var {
        return Object.keys(presets).filter(name => presets[name] === null || keys.every(key => saved.valid(key, presets[name][key])));
    }

    function selectedPreset(presets: var, keys: var): string {
        if (keys.every(key => !hasOverride(key)))
            return "Default";
        for (const name of presetNames(presets, keys)) {
            if (presets[name] !== null && keys.every(key => {
                const value = effective(key);
                const expected = presets[name][key];
                return typeof expected === "number" ? Math.abs(value - expected) <= 0.005 : value === expected;
            }))
                return name;
        }
        return "Custom";
    }

    function applyReactivePreset(name: string): void {
        if (!reactivePresetNames.includes(name))
            return;
        if (name === "Default")
            resetReactiveTuning();
        else
            saved.setMany(reactivePresets[name]);
    }

    function resetSpectrumTuning(): void {
        saved.resetMany(spectrumParameters.map(parameter => parameter.key).concat(spectrumSurfaces.map(surface => surface.key)));
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
                appearance.applyBlurSize();
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
        if (!vhsPresetNames.includes(name))
            return;
        if (name === "Default") {
            for (const key of vhsParameterKeys)
                clearOverride(key);
        } else {
            saved.setMany(vhsPresets[name]);
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
        const next = Math.round(runtime.bounded("appearance", "blurSize", value));
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
        toggleSpectrumMode("mediaVisualizerMode");
    }

    function toggleMediaLyrics(): void {
        storeOverride("mediaLyricsVisible", !mediaLyricsVisible);
    }
}
