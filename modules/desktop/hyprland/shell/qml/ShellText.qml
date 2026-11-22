import QtQuick

Text {
    required property RuntimeConfig runtime
    required property Theme theme

    color: theme.text
    font.family: runtime.fontSans
    font.pixelSize: theme.fontSize(13)
}
