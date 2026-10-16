pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    signal themeChanged
    property alias jsonAdapter: data
    readonly property var configData: root.jsonAdapter

    readonly property string terminal: root.configData.defaults.terminal
    readonly property string editor: root.configData.defaults.editor
    readonly property string wallpaper: root.configData.wallpaper
    readonly property string bluetoothctl: root.configData.tools.bluetoothctl
    readonly property string weatherCurl: Quickshell.env("LINUX_DESKTOP_WEATHER_CURL") || root.configData.tools.weatherCurl
    readonly property string agendaSetup: root.configData.tools.agendaSetup
    readonly property string agendaQuery: Quickshell.env("LINUX_DESKTOP_AGENDA_QUERY") || root.configData.tools.agendaQuery
    readonly property string brightnessctl: root.configData.tools.brightnessctl
    readonly property string cliphist: root.configData.tools.cliphist
    readonly property string emojiTest: root.configData.tools.emojiTest
    readonly property string resourceProbe: root.configData.tools.resourceProbe
    readonly property string clipboardCopy: root.configData.tools.clipboardCopy
    readonly property string clipboardPreview: root.configData.tools.clipboardPreview
    readonly property string lockSession: root.configData.tools.lockSession
    readonly property string networkConnectionEditor: root.configData.tools.networkConnectionEditor
    readonly property string nmcli: root.configData.tools.nmcli
    readonly property string hyprctl: root.configData.tools.hyprctl
    readonly property string powerprofilesctl: root.configData.tools.powerprofilesctl
    readonly property string powerprofilesMonitor: root.configData.tools.powerprofilesMonitor
    readonly property string sessionCommand: Quickshell.env("LINUX_DESKTOP_SESSION_COMMAND") || root.configData.tools.sessionCommand
    readonly property string themeSet: Quickshell.env("LINUX_DESKTOP_THEME_SET") || root.configData.tools.themeSet
    readonly property string wallpaperLibrary: root.configData.tools.wallpaperLibrary
    readonly property string recordingToggle: root.configData.tools.recordingToggle
    readonly property string recordingLibrary: root.configData.tools.recordingLibrary
    readonly property string notificationOpen: root.configData.tools.notificationOpen
    readonly property string frozenCapture: root.configData.tools.frozenCapture
    readonly property string colourPicker: root.configData.tools.colourPicker
    readonly property string nightLightControl: root.configData.tools.nightLightControl

    readonly property string fontMono: root.configData.fonts.mono

    readonly property color background: root.configData.theme.background
    readonly property color surface: root.configData.theme.surface
    readonly property color surfaceRaised: root.configData.theme.surfaceRaised
    readonly property color outline: root.configData.theme.outline
    readonly property color textMuted: root.configData.theme.textMuted
    readonly property color text: root.configData.theme.text
    readonly property color textStrong: root.configData.theme.textStrong
    readonly property color critical: root.configData.theme.critical
    readonly property color warning: root.configData.theme.warning
    readonly property color positive: root.configData.theme.positive
    readonly property color accent: root.configData.theme.accent

    readonly property real textScale: root.configData.accessibility.textScale
    readonly property bool animationsEnabled: root.configData.motion.animationsEnabled
    readonly property real panelOpacity: root.configData.visual.panelOpacity
    readonly property real focusOpacity: root.configData.visual.focusOpacity
    readonly property real scrimOpacity: root.configData.visual.scrimOpacity
    readonly property real squircleExponent: root.configData.visual.squircleExponent
    readonly property var keybindings: root.configData.keybindings
    readonly property var shortcuts: root.configData.shortcuts
    readonly property var shortcutHints: root.configData.shortcutHints

    function shortcut(id) {
        const value = shortcuts ? shortcuts[id] : undefined;
        return value === undefined || value === null ? "" : String(value);
    }

    function shortcutHint(id) {
        const value = shortcutHints ? shortcutHints[id] : undefined;
        return value === undefined || value === null ? "" : String(value);
    }

    property FileView configFile: FileView {
        path: Quickshell.env("LINUX_DESKTOP_RUNTIME") || ""
        blockLoading: true
        watchChanges: true
        onFileChanged: {
            reload();
            root.themeChanged();
        }

        JsonAdapter {
            id: data

            property JsonObject accessibility: JsonObject {
                property real textScale: 1.0
            }

            property JsonObject defaults: JsonObject {
                property string terminal: ""
                property string editor: ""
            }

            property JsonObject theme: JsonObject {
                property string background: "#111111"
                property string surface: "#1a1a1a"
                property string surfaceRaised: "#3a3a3a"
                property string outline: "#505050"
                property string textMuted: "#d0d0d0"
                property string text: "#f0f0f0"
                property string textStrong: "#ffffff"
                property string critical: "#ff7a5c"
                property string warning: "#ffd24a"
                property string positive: "#3de5f0"
                property string accent: "#33a8ff"
            }

            property JsonObject fonts: JsonObject {
                property string mono: "monospace"
            }

            property JsonObject motion: JsonObject {
                property bool animationsEnabled: true
            }

            property JsonObject visual: JsonObject {
                property real panelOpacity: 0.99
                property real focusOpacity: 0.96
                property real scrimOpacity: 0.50
                property real squircleExponent: 4.5
            }

            property JsonObject tools: JsonObject {
                property string bluetoothctl: ""
                property string weatherCurl: ""
                property string agendaQuery: ""
                property string agendaSetup: ""
                property string brightnessctl: ""
                property string cliphist: ""
                property string emojiTest: ""
                property string resourceProbe: ""
                property string clipboardCopy: ""
                property string clipboardPreview: ""
                property string lockSession: ""
                property string networkConnectionEditor: ""
                property string nmcli: ""
                property string hyprctl: ""
                property string powerprofilesctl: ""
                property string powerprofilesMonitor: ""
                property string sessionCommand: ""
                property string themeSet: ""
                property string wallpaperLibrary: ""
                property string recordingToggle: ""
                property string recordingLibrary: ""
                property string notificationOpen: ""
                property string frozenCapture: ""
                property string colourPicker: ""
                property string nightLightControl: ""
            }

            property var keybindings: []
            property var shortcuts: ({})
            property var shortcutHints: ({})
            property string wallpaper: ""
        }
    }
}
