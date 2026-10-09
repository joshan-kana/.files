pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root

    required property MediaState media
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property bool compact: false

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
                    action: "previous"
                },
                {
                    label: "−5s",
                    hint: "←",
                    enabled: root.media.seekable,
                    action: "back"
                },
                {
                    label: root.media.playing ? "Pause" : "Play",
                    hint: "Space",
                    enabled: root.media.canTogglePlaying,
                    action: "play"
                },
                {
                    label: "+5s",
                    hint: "→",
                    enabled: root.media.seekable,
                    action: "forward"
                },
                {
                    label: "▶",
                    hint: ".",
                    enabled: root.media.canGoNext,
                    action: "next"
                }
            ]

            delegate: ShellAction {
                required property var modelData
                width: modelData.action === "play" ? 108 : (root.compact ? 72 : 76)
                height: 40
                runtime: root.runtime
                theme: root.theme
                motion: root.motion
                compact: true
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
