pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// One notification service and queue, one viewport per compositor output.
// The shared frame receives each output's dock geometry from NotificationState.
Variants {
    id: outputs
    required property NotificationState notificationState
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property bool frameEnabled: false
    property bool hubVisible: false
    property var hubScreen: null
    property var hubBounds: null
    signal centerRequested(var screen)

    model: Quickshell.screens
    onModelChanged: notificationState.moveOrphanedPopups(Quickshell.screens.map(screen => screen.name))

    delegate: NotificationPopup {
        required property var modelData
        screen: modelData
        notificationState: outputs.notificationState
        runtime: outputs.runtime
        theme: outputs.theme
        motion: outputs.motion
        frameEnabled: outputs.frameEnabled
        hubVisible: outputs.hubVisible && outputs.hubScreen === screen
        hubBounds: outputs.hubBounds
        onCenterRequested: outputs.centerRequested(screen)
    }
}
