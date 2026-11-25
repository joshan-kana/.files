import QtQuick

Column {
    id: root

    required property RuntimeConfig runtime
    required property Theme theme

    property string title: ""
    property string detail: ""
    property bool emphasized: false
    property var hints: []
    property alias actions: headerActions.data
    default property alias contentData: body.data

    width: parent ? parent.width : implicitWidth
    spacing: theme.spacing2

    Row {
        width: parent.width
        height: Math.max(titleText.implicitHeight, detailText.implicitHeight, headerHints.implicitHeight, headerActions.implicitHeight)
        spacing: root.theme.spacing2

        ShellText {
            id: titleText
            anchors.verticalCenter: parent.verticalCenter
            runtime: root.runtime
            theme: root.theme
            text: root.title
            color: root.emphasized ? theme.readableColor(theme.commandColor, theme.panelBase) : theme.textStrong
            font.pixelSize: theme.fontSection
            font.weight: Font.DemiBold
            font.letterSpacing: 0
        }

        Item {
            width: Math.max(0, parent.width - titleText.implicitWidth - (headerActions.implicitWidth > 0 ? headerActions.implicitWidth : headerHints.visible ? headerHints.width : detailText.implicitWidth) - parent.spacing * 2)
            height: 1
        }

        ShellText {
            id: detailText
            anchors.verticalCenter: parent.verticalCenter
            visible: root.detail.length > 0 && root.hints.length === 0 && headerActions.implicitWidth === 0
            runtime: root.runtime
            theme: root.theme
            text: root.detail
            color: theme.textMuted
            font.pixelSize: theme.fontSupporting
        }

        KeyHintStrip {
            id: headerHints
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hints.length > 0 && headerActions.implicitWidth === 0
            width: visible ? Math.max(0, parent.width - titleText.implicitWidth - parent.spacing * 2) : 0
            runtime: root.runtime
            theme: root.theme
            hints: root.hints
            trailing: true
        }

        Row {
            id: headerActions
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.theme.spacing1
        }
    }

    Column {
        id: body
        width: parent.width
        spacing: root.theme.spacing2
    }
}
