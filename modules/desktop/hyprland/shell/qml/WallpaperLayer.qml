import QtQuick
import Quickshell
import Quickshell.Wayland

Variants {
    id: wallpaperLayer

    required property QtObject runtime
    required property QtObject theme

    model: Quickshell.screens

    delegate: PanelWindow {
        required property var modelData

        screen: modelData
        color: wallpaperLayer.theme.background
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            right: true
            bottom: true
            left: true
        }

        WlrLayershell.namespace: "linux-desktop-wallpaper"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Image {
            anchors.fill: parent
            source: wallpaperLayer.runtime.wallpaper
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
        }
    }
}
