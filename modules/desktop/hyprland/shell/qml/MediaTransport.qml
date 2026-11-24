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
    property int pressedIndex: -1
    // Only the responsive layout changes the delegate identities. Player
    // state updates bind to individual buttons, preserving in-flight feedback.
    readonly property var actions: [
        {
            action: "previous",
            glyph: "󰒮"
        },
        {
            action: "back",
            glyph: "󰒫"
        },
        {
            action: "play",
            glyph: "󰐊"
        },
        {
            action: "forward",
            glyph: "󰒬"
        },
        {
            action: "next",
            glyph: "󰒭"
        }
    ].filter(item => !simple || item.action === "previous" || item.action === "play" || item.action === "next")
    onSimpleChanged: pressedIndex = -1

    implicitWidth: buttons.implicitWidth
    implicitHeight: buttons.implicitHeight

    function canActivate(action: string): bool {
        switch (action) {
        case "previous":
            return media.canGoPrevious;
        case "next":
            return media.canGoNext;
        case "play":
            return media.canTogglePlaying;
        case "back":
        case "forward":
            return media.seekable;
        default:
            return false;
        }
    }

    function activate(action: string): void {
        if (!canActivate(action))
            return;
        switch (action) {
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

    function triggerAction(action: string, autoRepeat: bool): void {
        if (!canActivate(action) || (autoRepeat && action !== "back" && action !== "forward"))
            return;
        const index = actions.findIndex(item => item.action === action);
        const button = transportButtons.itemAt(index) as ShellAction;
        if (button)
            button.trigger();
        else
            activate(action);
    }

    function hint(action: string): string {
        switch (action) {
        case "previous":
            return runtime.shellHint(compact ? "MediaTransport.previousCompact" : "MediaTransport.previous");
        case "next":
            return runtime.shellHint(compact ? "MediaTransport.nextCompact" : "MediaTransport.next");
        case "back":
            return compact ? runtime.shellHint("MediaTransport.backCompact") : runtime.shellHint("MediaTransport.back");
        case "forward":
            return compact ? runtime.shellHint("MediaTransport.forwardCompact") : runtime.shellHint("MediaTransport.forward");
        default:
            return runtime.shellHint(compact ? "MediaTransport.playCompact" : "MediaTransport.play");
        }
    }

    function label(action: string): string {
        switch (action) {
        case "previous":
            return "Previous track";
        case "next":
            return "Next track";
        case "back":
            return "Seek backward " + media.seekSeconds + " seconds";
        case "forward":
            return "Seek forward " + media.seekSeconds + " seconds";
        default:
            return media.playing ? "Pause playback" : "Resume playback";
        }
    }

    Row {
        id: buttons
        spacing: root.theme.spacing2

        Repeater {
            id: transportButtons
            model: root.actions
            delegate: ShellAction {
                id: transportButton
                required property var modelData
                required property int index
                width: Math.max(implicitWidth, root.minimal ? (modelData.action === "play" ? 58 : 48) : (modelData.action === "play" ? 86 : 70))
                height: Math.max(!root.compact && !root.minimal && modelData.action === "play" ? 58 : 46, implicitHeight)
                anchors.verticalCenter: parent.verticalCenter
                runtime: root.runtime
                theme: root.theme
                motion: root.motion
                compact: true
                iconOnly: true
                iconHint: true
                connectedGroup: true
                neighborPressed: root.pressedIndex >= 0 && Math.abs(root.pressedIndex - index) === 1
                icon: modelData.action === "play" && root.media.playing ? "󰏤" : modelData.glyph
                title: root.label(modelData.action)
                shortcut: root.hint(modelData.action)
                prominentAction: modelData.action === "play" && !root.compact && !root.minimal && enabled
                activeColor: root.theme.roleColor("media")
                active: modelData.action === "play" && root.media.playing
                enabled: root.canActivate(modelData.action)
                onVisualPressedChanged: {
                    if (visualPressed)
                        root.pressedIndex = index;
                    else if (root.pressedIndex === index)
                        root.pressedIndex = -1;
                }
                onActivated: root.activate(modelData.action)
            }
        }
    }
}
