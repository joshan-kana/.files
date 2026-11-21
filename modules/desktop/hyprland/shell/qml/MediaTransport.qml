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
    property bool simple: false

    implicitWidth: buttons.implicitWidth
    implicitHeight: buttons.implicitHeight

    Row {
        id: buttons
        spacing: root.theme.spacing2

        Repeater {
            model: [
                {
                    label: "Previous track",
                    hint: root.runtime.shellHint("MediaTransport.previous"),
                    enabled: root.media.canGoPrevious,
                    action: "previous",
                    glyph: "󰒮"
                },
                {
                    label: "Seek backward " + root.media.seekSeconds + " seconds",
                    hint: root.compact ? root.runtime.shellHint("MediaTransport.backCompact") : root.runtime.shellHint("MediaTransport.back"),
                    enabled: root.media.seekable,
                    action: "back",
                    glyph: "󰒫"
                },
                {
                    label: root.media.playing ? "Pause playback" : "Resume playback",
                    hint: root.runtime.shellHint("MediaTransport.play"),
                    enabled: root.media.canTogglePlaying,
                    action: "play",
                    glyph: root.media.playing ? "󰏤" : "󰐊"
                },
                {
                    label: "Seek forward " + root.media.seekSeconds + " seconds",
                    hint: root.compact ? root.runtime.shellHint("MediaTransport.forwardCompact") : root.runtime.shellHint("MediaTransport.forward"),
                    enabled: root.media.seekable,
                    action: "forward",
                    glyph: "󰒬"
                },
                {
                    label: "Next track",
                    hint: root.runtime.shellHint("MediaTransport.next"),
                    enabled: root.media.canGoNext,
                    action: "next",
                    glyph: "󰒭"
                }
            ].filter(item => !root.simple || item.action === "previous" || item.action === "play" || item.action === "next")

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
                        root.media.seekStep(-1);
                        break;
                    case "play":
                        root.media.togglePlaying();
                        break;
                    case "forward":
                        root.media.seekStep(1);
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
