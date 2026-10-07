import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    signal themeChanged

    readonly property string terminal: data.defaults.terminal
    readonly property string editor: data.defaults.editor
    readonly property string wallpaper: data.wallpaper
    readonly property string bluetoothctl: data.tools.bluetoothctl
    readonly property string brightnessctl: data.tools.brightnessctl
    readonly property string cliphist: data.tools.cliphist
    readonly property string clipboardCopy: data.tools.clipboardCopy
    readonly property string lockSession: data.tools.lockSession
    readonly property string networkConnectionEditor: data.tools.networkConnectionEditor
    readonly property string sessionCommand: Quickshell.env("LINUX_DESKTOP_SESSION_COMMAND") || data.tools.sessionCommand
    readonly property string themeSet: Quickshell.env("LINUX_DESKTOP_THEME_SET") || data.tools.themeSet

    readonly property string fontMono: data.fonts.mono

    readonly property color background: data.theme.background
    readonly property color surface: data.theme.surface
    readonly property color surfaceRaised: data.theme.surfaceRaised
    readonly property color outline: data.theme.outline
    readonly property color textMuted: data.theme.textMuted
    readonly property color text: data.theme.text
    readonly property color textStrong: data.theme.textStrong
    readonly property color critical: data.theme.critical
    readonly property color warning: data.theme.warning
    readonly property color positive: data.theme.positive
    readonly property color accent: data.theme.accent

    readonly property real textScale: data.accessibility.textScale
    readonly property bool animationsEnabled: data.motion.animationsEnabled
    readonly property real panelOpacity: data.visual.panelOpacity
    readonly property real focusOpacity: data.visual.focusOpacity
    readonly property real scrimOpacity: data.visual.scrimOpacity
    readonly property real squircleExponent: data.visual.squircleExponent
    readonly property var keybindings: data.keybindings
    readonly property var shortcuts: data.shortcuts

    function shortcut(id) {
        const value = shortcuts ? shortcuts[id] : undefined;
        return value === undefined || value === null ? "" : String(value);
    }

    property FileView themeStateFile: FileView {
        path: Quickshell.env("LINUX_DESKTOP_THEME_STATE") || ""
        watchChanges: true
        onFileChanged: {
            configFile.reload();
            root.themeChanged();
        }
    }

    property FileView configFile: FileView {
        path: Quickshell.env("LINUX_DESKTOP_RUNTIME") || ""
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()

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
                property string brightnessctl: ""
                property string cliphist: ""
                property string clipboardCopy: ""
                property string lockSession: ""
                property string networkConnectionEditor: ""
                property string sessionCommand: ""
                property string themeSet: ""
            }

            property var keybindings: []
            property var shortcuts: ({})
            property string wallpaper: ""
        }
    }
}
