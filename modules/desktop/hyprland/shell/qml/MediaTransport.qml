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
                    label: "◀",
                    hint: ",",
                    enabled: root.media.canGoPrevious,
                    action: "previous",
                    glyph: "󰒮"
                },
                {
                    label: "−5s",
                    hint: root.compact ? "⇧H" : "←",
                    enabled: root.media.seekable,
                    action: "back",
                    glyph: "󰒫"
                },
                {
                    label: root.media.playing ? "Pause" : "Play",
                    hint: "Space",
                    enabled: root.media.canTogglePlaying,
                    action: "play",
                    glyph: root.media.playing ? "󰏤" : "󰐊"
                },
                {
                    label: "+5s",
                    hint: root.compact ? "⇧L" : "→",
                    enabled: root.media.seekable,
                    action: "forward",
                    glyph: "󰒬"
                },
                {
                    label: "▶",
                    hint: ".",
                    enabled: root.media.canGoNext,
                    action: "next",
                    glyph: "󰒭"
                }
            ]

            delegate: ShellAction {
                required property var modelData
                width: root.minimal ? (modelData.action === "play" ? 45 : 34) : modelData.action === "play" ? 108 : (root.compact ? 72 : 76)
                height: root.minimal ? 36 : 40
                runtime: root.runtime
                theme: root.theme
                motion: root.motion
                compact: true
                iconOnly: root.minimal
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
