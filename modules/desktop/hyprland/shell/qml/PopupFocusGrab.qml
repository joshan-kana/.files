pragma ComponentBehavior: Bound
import Quickshell.Hyprland

HyprlandFocusGrab {
    required property var popup
    property bool suspended: false
    signal dismissed

    // The compositor can activate an exclusive layer well after its first
    // frame. Focus the live popup surface explicitly instead of waiting for
    // that layer-shell handoff. No process launch or timing heuristic.
    active: popup.open && !suspended
    windows: [popup]
    onCleared: dismissed()
}
