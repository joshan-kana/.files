import QtQuick
import Quickshell.Hyprland

// Compositor submap events are the authoritative input-mode transition.
// The visible feedback never owns or changes the active compositor submap.
QtObject {
    id: state
    property string submap: "reset"
    readonly property bool passthroughActive: submap === "passthru"

    property Connections compositorEvents: Connections {
        target: Hyprland
        function onRawEvent(event): void {
            if (event.name !== "submap")
                return;
            const active = String(event.data || "").trim();
            state.submap = active.length > 0 ? active : "reset";
        }
    }
}
