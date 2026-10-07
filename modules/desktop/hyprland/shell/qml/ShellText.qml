import QtQuick

Text {
    required property QtObject runtime
    required property QtObject theme

    color: theme.text
    font.family: runtime.fontMono
    font.pixelSize: theme.fontSize(13)
}
