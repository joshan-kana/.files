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
            model: root.compact ? [
                {
                    label: "◀",
                    hint: ",",
                    enabled: root.media.available,
                    action: "previous"
                },
                {
                    label: root.media.playing ? "Pause" : "Play",
                    hint: "Space",
                    enabled: root.media.available,
                    action: "play"
                },
                {
                    label: "▶",
                    hint: ".",
                    enabled: root.media.available,
                    action: "next"
                }
            ] : [
                {
                    label: "◀",
                    hint: ",",
                    enabled: root.media.available,
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
                    enabled: root.media.available,
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
                    enabled: root.media.available,
                    action: "next"
                }
            ]

            delegate: ShellAction {
                required property var modelData
                width: root.compact ? (modelData.action === "play" ? 108 : 70) : (modelData.action === "play" ? 108 : 76)
                height: 40
                runtime: root.runtime
                theme: root.theme
                motion: root.motion
                compact: true
                title: modelData.hint + "  " + modelData.label
                active: modelData.action === "play"
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
