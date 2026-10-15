pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// Keep the Wayland backing layer mapped while suppressing closed panel
// content, input and redundant rendering without resizing the backing window.
Item {
    id: lifecycle
    required property var popup
    required property bool exposed
    // Render the configured viewport once at startup and retain that size
    // while closed. Only the content and subsequent idle frame updates stop,
    // avoiding a compositor resize on the next popup opening.
    property bool prewarm: false
    property bool preparing: prewarm
    property real fullWidth: popup && popup.screen ? popup.screen.width : 1
    property real fullHeight: popup && popup.screen ? popup.screen.height : 1
    readonly property bool expanded: exposed || preparing
    // Keep rendering until the compositor receives a fully transparent
    // closing frame. Instantly stopping updates can leave a ghost panel.
    property bool clearFramePending: true
    readonly property bool needsRendering: exposed || preparing || clearFramePending
    onExposedChanged: {
        if (!exposed)
            clearFramePending = true;
    }

    Connections {
        target: lifecycle.popup && lifecycle.popup.contentItem ? lifecycle.popup.contentItem.Window.window : null
        function onFrameSwapped() {
            if (!lifecycle.exposed && lifecycle.clearFramePending)
                lifecycle.clearFramePending = false;
            if (lifecycle.preparing && lifecycle.popup.width >= lifecycle.fullWidth - 1 && lifecycle.popup.height >= lifecycle.fullHeight - 1)
                lifecycle.preparing = false;
        }
    }

    width: 0
    height: 0
    visible: false
    property Item interactiveItem: popup.contentItem
    readonly property Region inputRegion: Region {
        item: lifecycle.exposed ? lifecycle.interactiveItem : lifecycle
    }
    Binding {
        target: lifecycle.popup.contentItem
        property: "opacity"
        value: lifecycle.exposed ? 1 : 0
    }
}
