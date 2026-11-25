pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "ShellKeybindings.js" as ShellKeybindings

QtObject {
    id: root

    signal themeChanged
    readonly property var themeAdapter: parseTheme(themeFile.text(), configData.fallbackTheme)
    readonly property var configData: parseConfig(configFile.text())

    readonly property string terminal: root.configData.defaults.terminal
    readonly property string editor: root.configData.defaults.editor
    readonly property string wallpaper: root.themeAdapter.wallpaper
    readonly property string bluetoothctl: root.configData.tools.bluetoothctl
    readonly property string weatherCurl: Quickshell.env("DESKTOP_SHELL_WEATHER_CURL") || root.configData.tools.weatherCurl
    readonly property string agendaSetup: root.configData.tools.agendaSetup
    readonly property string agendaQuery: Quickshell.env("DESKTOP_SHELL_AGENDA_QUERY") || root.configData.tools.agendaQuery
    readonly property string brightnessctl: root.configData.tools.brightnessctl
    readonly property string cliphist: root.configData.tools.cliphist
    readonly property string emojiTest: root.configData.tools.emojiTest
    readonly property string resourceProbe: root.configData.tools.resourceProbe
    readonly property string copyText: root.configData.tools.copyText
    readonly property string clipboardCopy: root.configData.tools.clipboardCopy
    readonly property string clipboardPreview: root.configData.tools.clipboardPreview
    readonly property string clipboardOperations: root.configData.tools.clipboardOperations
    readonly property string lockSession: root.configData.tools.lockSession
    readonly property string networkConnectionEditor: root.configData.tools.networkConnectionEditor
    readonly property string pwMetadata: root.configData.tools.pwMetadata
    readonly property string pwDump: root.configData.tools.pwDump
    readonly property string wpctl: root.configData.tools.wpctl
    readonly property string timeout: root.configData.tools.timeout
    readonly property string busctl: root.configData.tools.busctl
    readonly property string nmcli: root.configData.tools.nmcli
    readonly property string hyprctl: root.configData.tools.hyprctl
    readonly property string easyeffectsCli: root.configData.tools.easyeffectsCli
    readonly property string easyeffects: root.configData.tools.easyeffects
    readonly property string vhsControl: root.configData.tools.vhsControl
    readonly property string sessionCommand: Quickshell.env("DESKTOP_SHELL_SESSION_COMMAND") || root.configData.tools.sessionCommand
    readonly property string themeSet: Quickshell.env("DESKTOP_SHELL_THEME_SET") || root.themeAdapter.tools.themeSet
    readonly property string urlOpen: root.configData.tools.urlOpen
    readonly property string paletteSearch: root.configData.tools.paletteSearch
    readonly property string clipboardPaste: root.configData.tools.clipboardPaste
    readonly property string wallpaperPolicy: root.configData.tools.wallpaperPolicy
    readonly property string wallpaperLibrary: root.configData.tools.wallpaperLibrary
    readonly property string recordingToggle: root.configData.tools.recordingToggle
    readonly property string captureLocations: root.configData.tools.captureLocations
    readonly property string recordingLibrary: root.configData.tools.recordingLibrary
    readonly property string frozenCapture: root.configData.tools.frozenCapture
    readonly property string colourPicker: root.configData.tools.colourPicker
    readonly property string nightLightControl: root.configData.tools.nightLightControl
    readonly property string displayControl: root.configData.tools.displayControl
    readonly property string displaySettings: root.configData.tools.displaySettings
    readonly property string notifySend: root.configData.tools.notifySend

    readonly property string fontSans: root.themeAdapter.fonts.sans
    readonly property string fontSerif: root.themeAdapter.fonts.serif
    readonly property string fontMono: root.themeAdapter.fonts.mono

    readonly property color background: root.themeAdapter.theme.background
    readonly property color surface: root.themeAdapter.theme.surface
    readonly property color surfaceRaised: root.themeAdapter.theme.surfaceRaised
    readonly property color outline: root.themeAdapter.theme.outline
    readonly property color textMuted: root.themeAdapter.theme.textMuted
    readonly property color text: root.themeAdapter.theme.text
    readonly property color textStrong: root.themeAdapter.theme.textStrong
    readonly property color critical: root.themeAdapter.theme.critical
    readonly property color warning: root.themeAdapter.theme.warning
    readonly property color positive: root.themeAdapter.theme.positive
    readonly property color accent: root.themeAdapter.theme.accent
    readonly property color accentSecondary: root.themeAdapter.theme.accentSecondary
    readonly property color accentTertiary: root.themeAdapter.theme.accentTertiary
    readonly property color accentWarm: root.themeAdapter.theme.accentWarm
    readonly property color accentWorkspace: root.themeAdapter.theme.accentWorkspace
    readonly property color accentUtility: root.themeAdapter.theme.accentUtility
    readonly property color accentEnergy: root.themeAdapter.theme.accentEnergy
    readonly property color accentNature: root.themeAdapter.theme.accentNature
    readonly property var roleColors: root.themeAdapter.roles

    readonly property real textScale: root.configData.accessibility.textScale
    readonly property real motionDurationMultiplier: root.configData.motion.durationMultiplier
    readonly property var resourceSampling: root.configData.resourceSampling
    readonly property bool animationsEnabled: root.configData.motion.animationsEnabled
    readonly property bool restoreWindowsOnExit: root.configData.session.restoreWindowsOnExit
    readonly property real panelOpacity: root.themeAdapter.visual.panelOpacity
    readonly property real focusOpacity: root.themeAdapter.visual.focusOpacity
    readonly property real scrimOpacity: root.themeAdapter.visual.scrimOpacity
    readonly property real squircleExponent: root.themeAdapter.visual.squircleExponent
    readonly property var keybindings: root.configData.keybindings
    readonly property var shortcuts: root.configData.shortcuts
    readonly property var shortcutHints: root.configData.shortcutHints
    readonly property var shellBindings: root.configData.shellBindings
    readonly property var paletteQuicklinks: root.configData.palette.quicklinks
    readonly property var paletteSnippets: root.configData.palette.snippets
    readonly property var constraints: root.configData.constraints
    function bounded(group: string, key: string, value: real): real {
        const range = constraints[group][key];
        return Math.max(range.min, Math.min(range.max, value));
    }

    readonly property var appearanceDefaults: root.configData.appearance
    readonly property var captureEncoding: root.configData.capture.encoding
    readonly property bool captureFreezeEnabled: root.configData.capture.freezeEnabled
    readonly property bool notificationSilent: root.configData.notifications.silent
    readonly property bool notificationPresentation: root.configData.notifications.presentation
    readonly property bool notificationHistoryEnabled: root.configData.notifications.historyEnabled
    readonly property var notificationApplications: root.configData.notifications.applications
    readonly property var notificationQuietHours: root.configData.notifications.quietHours
    readonly property string weatherUnits: root.configData.weather.units
    readonly property string weatherLocation: root.configData.weather.location

    function shortcut(id) {
        const value = shortcuts ? shortcuts[id] : undefined;
        return value === undefined || value === null ? "" : String(value);
    }

    function shortcutHint(id) {
        const value = shortcutHints ? shortcutHints[id] : undefined;
        return value === undefined || value === null ? "" : String(value);
    }

    // The action's declared slot owns both keyboard matching and its hint.
    // Scope overrides may change a panel without modifying other shell views.
    function shellKeyCode(scope: string, slot: string): int {
        return ShellKeybindings.keyCode(shellBindings, scope, slot, Qt);
    }

    function shellNavigates(scope: string, direction: string, key: int, mode = "all"): bool {
        return ShellKeybindings.navigates(shellBindings, scope, direction, key, Qt, mode);
    }

    function shellModifier(scope: string, slot: string, modifiers: int): bool {
        return ShellKeybindings.modifier(shellBindings, scope, slot, modifiers, Qt);
    }

    function shellHint(action: string): string {
        return ShellKeybindings.hint(shellBindings, action);
    }

    function shellSequence(action: string): string {
        return ShellKeybindings.sequence(shellBindings, action);
    }

    function shellMatchesHint(action: string, key: int, modifiers: int): bool {
        return ShellKeybindings.matchesHint(shellBindings, action, key, modifiers, Qt);
    }

    function shellChoiceIndex(key: int, modifiers: int, count: int): int {
        return ShellKeybindings.widgetChoiceIndex(shellBindings, key, modifiers, count, Qt);
    }

    function shellChoiceHint(index: int): string {
        return ShellKeybindings.widgetChoiceHint(shellBindings, index);
    }

    function shellNumberIndex(scope: string, key: int, count: int): int {
        return ShellKeybindings.numberIndex(shellBindings, scope, key, count, Qt);
    }

    function shellNumberHint(scope: string, index: int): string {
        return ShellKeybindings.numberHint(shellBindings, scope, index);
    }

    property FileView themeFile: FileView {
        path: Quickshell.env("DESKTOP_SHELL_THEME") || root.configFile.path.replace(/runtime\.json$/, "theme.json")
        blockLoading: true
        watchChanges: true
        onFileChanged: {
            reload();
            root.themeChanged();
        }

        printErrors: false
    }

    // An optional Stylix theme may be absent. Both presentations come from
    // the same Nix mapping; missing or malformed fields use its fallback.
    function parseTheme(text: string, fallback: var): var {
        let selected;
        try {
            selected = JSON.parse(text);
        } catch (_) {
            return fallback;
        }
        if (!selected || typeof selected !== "object")
            return fallback;
        const result = Object.assign({}, fallback);
        for (const group of Object.keys(fallback)) {
            const baseline = fallback[group];
            const incoming = selected[group];
            if (typeof baseline === "object") {
                result[group] = Object.assign({}, baseline);
                for (const key of Object.keys(baseline)) {
                    const value = incoming?.[key];
                    if (typeof value === typeof baseline[key] && (typeof value !== "number" || Number.isFinite(value)))
                        result[group][key] = value;
                }
            } else if (typeof incoming === typeof baseline) {
                result[group] = incoming;
            }
        }
        return result;
    }

    // Runtime configuration is evaluated by Nix; missing configuration is
    // an installation error, not another source of preference defaults.
    function parseConfig(text: string): var {
        try {
            const config = JSON.parse(text);
            for (const key of ["fallbackTheme", "constraints", "accessibility", "defaults", "motion", "resourceSampling", "session", "palette", "appearance", "capture", "notifications", "weather", "tools", "shortcuts", "shortcutHints", "shellBindings", "nightLight", "wallpaperRotation"]) {
                if (!config[key] || typeof config[key] !== "object" || Array.isArray(config[key]))
                    throw new Error("Missing runtime configuration object: " + key);
            }
            if (!Array.isArray(config.keybindings))
                throw new Error("Missing runtime keybindings");
            return config;
        } catch (error) {
            console.error("Invalid desktop-shell runtime configuration: " + error.message);
            Qt.exit(1);
            throw error;
        }
    }

    property FileView configFile: FileView {
        path: Quickshell.env("DESKTOP_SHELL_RUNTIME") || ""
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }
}
