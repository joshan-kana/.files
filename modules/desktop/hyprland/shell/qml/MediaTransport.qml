pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root

    required property MediaState media
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property bool compact: false
    property bool minimal: false

    implicitWidth: buttons.implicitWidth
    implicitHeight: buttons.implicitHeight

    Row {
        id: buttons
        spacing: root.theme.spacing2

        Repeater {
            model: [
                {
                    label: "Previous track",
                    hint: ",",
                    enabled: root.media.canGoPrevious,
                    action: "previous",
                    glyph: "󰒮"
                },
                {
                    label: "Seek backward five seconds",
                    hint: root.compact ? "SHIFT+H" : "H",
                    enabled: root.media.seekable,
                    action: "back",
                    glyph: "󰒫"
                },
                {
                    label: root.media.playing ? "Pause playback" : "Resume playback",
                    hint: "Space",
                    enabled: root.media.canTogglePlaying,
                    action: "play",
                    glyph: root.media.playing ? "󰏤" : "󰐊"
                },
                {
                    label: "Seek forward five seconds",
                    hint: root.compact ? "SHIFT+L" : "L",
                    enabled: root.media.seekable,
                    action: "forward",
                    glyph: "󰒬"
                },
                {
                    label: "Next track",
                    hint: ".",
                    enabled: root.media.canGoNext,
                    action: "next",
                    glyph: "󰒭"
                }
            ]

            delegate: ShellAction {
                required property var modelData
                width: root.minimal ? (modelData.action === "play" ? 58 : 48) : (modelData.action === "play" ? 86 : 70)
                height: 46
                runtime: root.runtime
                theme: root.theme
                motion: root.motion
                compact: true
                iconOnly: true
                iconHint: true
                icon: modelData.glyph
                title: modelData.label
                shortcut: modelData.hint
                active: modelData.action === "play" && root.media.playing
                enabled: modelData.enabled

                onActivated: {
                    switch (modelData.action) {
                    case "previous":
                        root.media.previous();
                        break;
                    case "back":
                        root.media.seek(-5);
                        break;
                    case "play":
                        root.media.togglePlaying();
                        break;
                    case "forward":
                        root.media.seek(5);
                        break;
                    case "next":
                        root.media.next();
                        break;
                    }
                }
            }
        }
    }
}
