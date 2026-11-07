pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

// Keep the ordinary global modals on one stable compact layer. Their QML
// trees are built at shell startup and only Item visibility changes on keys.
PanelWindow {
    id: host
    required property ScreenRouter screens
    required property ClipboardPanel clipboardPanel
    required property CommandPalette launcher
    required property OverviewPanel overviewPanel
    required property ShortcutCheatsheet cheatsheet

    readonly property var activePanel: cheatsheet.open ? cheatsheet : launcher.open ? launcher : clipboardPanel.open ? clipboardPanel : overviewPanel.open ? overviewPanel : null
    readonly property bool open: activePanel !== null
    readonly property bool transitioning: clipboardPanel.closing || launcher.closing || overviewPanel.closing || cheatsheet.closing
    readonly property bool contentVisible: open || transitioning
    // A separate 1×1 Top-layer trigger dims only ordinary modal panels.
    readonly property bool dimActive: open || transitioning

    screen: screens.focusedScreen || Quickshell.screens[0]
    visible: true
    updatesEnabled: surfaceLifecycle.needsRendering
    color: "transparent"
    focusable: open && !(overviewPanel.open && overviewPanel.keyboardFocusRefreshing)
    exclusionMode: ExclusionMode.Ignore
    // Use one stable modal viewport for every ordinary widget. Resizing it
    // from 1200×960 to the cheatsheet's larger bounds on first open caused
    // the compositor to recenter its layer while content was appearing.
    // Keep the allocated window stationary; PopupSurfaceLifecycle suppresses
    // rendering and input while all modals are closed.
    implicitWidth: Math.min(screen ? screen.width - 80 : 1850, 1850)
    implicitHeight: Math.min(screen ? screen.height - 80 : 1170, 1170)
    anchors {
        top: true
        left: true
    }
    margins {
        top: !screen ? 0 : Math.max(0, Math.floor((screen.height - implicitHeight) / 2))
        left: !screen ? 0 : Math.max(0, Math.floor((screen.width - implicitWidth) / 2))
    }
    WlrLayershell.namespace: "linux-desktop-modal"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: focusable ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Closed modals never intercept pointer input from background apps.
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
            if (host.activePanel)
                host.activePanel.hide();
        }
    }
}
