import QtQuick

Text {
    required property RuntimeConfig runtime
    required property Theme theme

    enum Role {
        Body,
        Supporting,
        Utility,
        Action,
        Section,
        Title,
        Readback,
        Display
    }
    property int textRole: ShellText.Body
    color: textRole === ShellText.Supporting || textRole === ShellText.Utility ? theme.readableColor(theme.textMuted, theme.panelBase) : textRole === ShellText.Readback ? theme.readableColor(theme.valueColor, theme.panelBase) : textRole === ShellText.Display ? theme.textBright : theme.text
    font.family: textRole === ShellText.Readback || textRole === ShellText.Display ? runtime.fontMono : runtime.fontSans
    font.pixelSize: [theme.fontAction, theme.fontSupporting, theme.fontUtility, theme.fontAction, theme.fontSection, theme.fontDetailTitle, theme.fontReadback, theme.fontDisplay][textRole]
    font.weight: textRole >= ShellText.Action ? Font.DemiBold : Font.Normal
}
