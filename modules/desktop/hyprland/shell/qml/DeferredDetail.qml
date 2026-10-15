pragma ComponentBehavior: Bound
import QtQuick

// Incubate detail content independently of the primary Controls surface.
// Once constructed, keep it alive across navigation and hub close/reopen.
Loader {
    id: detail
    asynchronous: true
    active: false

    readonly property var panel: item
    property bool pendingOpen: false
    property var pendingMenuItem: null
    readonly property bool open: panel ? !!panel.open : pendingOpen
    readonly property bool operationRunning: !!(panel && panel.operationRunning)
    readonly property bool statusError: !!(panel && panel.statusError)
    readonly property bool passwordPrompt: !!(panel && panel.passwordPrompt)
    readonly property bool detailView: !!(panel && panel.detailView)
    readonly property bool savedView: !!(panel && panel.savedView)
    readonly property bool profileActionRunning: !!(panel && panel.profileAction && panel.profileAction.running)
    readonly property var pendingNetwork: panel ? panel.pendingNetwork : null
    readonly property string deletePending: panel && panel.deletePending ? panel.deletePending : ""
    readonly property int itemCount: panel && panel.itemCount ? panel.itemCount : 0

    function prewarm(): void {
        active = true;
    }

    function finishLoading(): void {
        active = true;
        // A request during incubation must never reveal an empty detail panel.
        if (!panel && asynchronous)
            asynchronous = false;
    }

    function openView(): void {
        pendingOpen = true;
        if (panel)
            panel.openView();
        else
            finishLoading();
    }

    function closeView(): void {
        pendingOpen = false;
        if (panel)
            panel.closeView();
    }

    function openFor(entry: var): void {
        pendingOpen = true;
        pendingMenuItem = entry;
        if (panel)
            panel.openFor(entry);
        else
            finishLoading();
    }

    function closeMenu(): void {
        pendingOpen = false;
        pendingMenuItem = null;
        if (panel)
            panel.closeMenu();
    }

    function invoke(method: string, ...args) {
        // Keyboard input can arrive while this view is still incubating.
        // Finish construction in that case rather than dropping the action.
        if (!panel)
            finishLoading();
        if (panel && typeof panel[method] === "function")
            return panel[method](...args);
        console.warn("Unavailable detail action:", method);
        return undefined;
    }

    onLoaded: {
        if (!pendingOpen || !item)
            return;
        if (pendingMenuItem)
            panel.openFor(pendingMenuItem);
        else
            panel.openView();
    }
}
