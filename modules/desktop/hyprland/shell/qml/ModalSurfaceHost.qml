pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// One mapped layer and framebuffer for all global modal actions. Their QML
// trees are built at shell startup and only Item visibility changes on keys.
PanelWindow {
    id: host
    required property ScreenRouter screens
    required property ClipboardPanel clipboardPanel
    required property CommandPalette launcher
    required property OverviewPanel overviewPanel
    required property AudioMixerPanel audioMixerPanel
    required property ShortcutCheatsheet cheatsheet
    required property ScreenshotPicker screenshotPicker

    readonly property var activePanel: screenshotPicker.open ? screenshotPicker : cheatsheet.open ? cheatsheet : launcher.open ? launcher : clipboardPanel.open ? clipboardPanel : overviewPanel.open ? overviewPanel : audioMixerPanel.open ? audioMixerPanel : null
    readonly property bool open: activePanel !== null
    readonly property bool transitioning: clipboardPanel.closing || launcher.closing || overviewPanel.closing || audioMixerPanel.closing || cheatsheet.closing
    readonly property bool contentVisible: open || transitioning
    readonly property bool captureExpanded: screenshotPicker.open
    // A sole compact surface avoids the permanent fullscreen modal framebuffer.
    // The frozen region screenshot temporarily expands this host to the output.
    // The PR dims these five modal widgets, but not the hub, notifications,
    // OSD, or region capture. The dim strength is deliberately subtle and
    // configured by Hyprland to avoid the previous blanket dark backdrop.
    readonly property bool dimActive: !captureExpanded && (launcher.open || cheatsheet.open || clipboardPanel.open || overviewPanel.open || audioMixerPanel.open)

    function syncCompositorDim(): void {
        Hyprland.dispatch("(function() if linux_desktop_modal_dim_rule then linux_desktop_modal_dim_rule:set_enabled(" + (host.dimActive ? "true" : "false") + ") end; return hl.dsp.no_op() end)()");
    }
    onDimActiveChanged: syncCompositorDim()
    Component.onCompleted: {
        Hyprland.dispatch('(function() if linux_desktop_modal_dim_rule then linux_desktop_modal_dim_rule:set_enabled(false) end; linux_desktop_modal_dim_rule=hl.layer_rule({name="linux-desktop-modal-dim",match={namespace="^linux-desktop-modal$"},dim_around=true});linux_desktop_modal_dim_rule:set_enabled(false);return hl.dsp.no_op() end)()');
    }
    Component.onDestruction: {
        Hyprland.dispatch('(function() if linux_desktop_modal_dim_rule then linux_desktop_modal_dim_rule:set_enabled(false);linux_desktop_modal_dim_rule=nil end;return hl.dsp.no_op() end)()');
    }

    screen: screenshotPicker.open && screenshotPicker.captureScreen ? screenshotPicker.captureScreen : screens.focusedScreen || Quickshell.screens[0]
    visible: true
    updatesEnabled: surfaceLifecycle.needsRendering
    color: "transparent"
    focusable: open && !(overviewPanel.open && overviewPanel.keyboardFocusRefreshing)
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: captureExpanded ? (screen ? screen.width : 2560) : 1200
    implicitHeight: captureExpanded ? (screen ? screen.height : 1440) : 960
    anchors {
        top: true
        left: true
    }
    margins {
        top: captureExpanded || !screen ? 0 : Math.max(0, Math.floor((screen.height - implicitHeight) / 2))
        left: captureExpanded || !screen ? 0 : Math.max(0, Math.floor((screen.width - implicitWidth) / 2))
    }
    WlrLayershell.namespace: "linux-desktop-modal"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: focusable ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Idle input goes straight through the fullscreen transparent backing
    // surface; background apps never receive a ghost pointer blocker.
    PopupSurfaceLifecycle {
        id: surfaceLifecycle
        popup: host
        exposed: host.contentVisible
    }
    mask: surfaceLifecycle.inputRegion

    PopupFocusGrab {
        popup: host
        suspended: host.overviewPanel.open && host.overviewPanel.keyboardFocusRefreshing
        onDismissed: {
            if (host.activePanel === host.screenshotPicker)
                host.screenshotPicker.dismiss(true);
            else if (host.activePanel)
                host.activePanel.hide();
        }
    }
}
