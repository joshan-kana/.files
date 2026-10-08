import QtQuick

Column {
    id: root

    required property RuntimeConfig runtime
    required property Theme theme

    property string title: ""
    property string detail: ""
    default property alias contentData: body.data

    width: parent ? parent.width : implicitWidth
    spacing: theme.spacing2

    Row {
        width: parent.width
        spacing: root.theme.spacing2

        ShellText {
            runtime: root.runtime
            theme: root.theme
            text: root.title
            color: theme.textStrong
            font.pixelSize: theme.fontSize(11)
            font.weight: Font.DemiBold
        }

        Item {
            width: Math.max(0, parent.width - parent.children[0].width - detailText.width - parent.spacing * 2)
            height: 1
        }

        ShellText {
            id: detailText
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
