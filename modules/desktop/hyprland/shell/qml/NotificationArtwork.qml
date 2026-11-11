pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Image {
    id: artwork
    required property var notification
    property bool preview: false

    source: !notification ? "" : preview ? notification.image || "" : Quickshell.iconPath(notification.appIcon || "application-x-executable", "application-x-executable")
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    sourceSize: Qt.size(Math.max(1, Math.ceil(width * 2)), Math.max(1, Math.ceil(height * 2)))
}
