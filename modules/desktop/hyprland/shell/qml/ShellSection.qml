import QtQuick

Column {
    id: root

    required property RuntimeConfig runtime
    required property Theme theme

    property string title: ""
    property string detail: ""
    property bool emphasized: false
    property string accentRole: ""
    default property alias contentData: body.data

    width: parent ? parent.width : implicitWidth
    spacing: theme.spacing2

    Row {
        width: parent.width
        height: Math.max(titleText.implicitHeight, detailText.implicitHeight)
        spacing: root.theme.spacing2

        ShellText {
            id: titleText
            anchors.verticalCenter: parent.verticalCenter
            runtime: root.runtime
            theme: root.theme
            text: root.emphasized ? root.title.toUpperCase() : root.title
            color: root.emphasized ? theme.readableRoleColor(root.accentRole) : theme.textStrong
            font.pixelSize: root.emphasized ? theme.fontPanelEyebrow : theme.fontSize(11)
            font.weight: Font.DemiBold
            font.letterSpacing: root.emphasized ? 0.8 : 0
        }

        Item {
            width: Math.max(0, parent.width - parent.children[0].width - detailText.width - parent.spacing * 2)
            height: 1
        }

        ShellText {
            id: detailText
            anchors.verticalCenter: parent.verticalCenter
            visible: root.detail.length > 0
            runtime: root.runtime
            theme: root.theme
            text: root.detail
            color: theme.textMuted
            font.pixelSize: theme.fontSize(9)
        }
    }

    Column {
        id: body
        width: parent.width
        spacing: root.theme.spacing2
    }
}
