import QtQuick

Column {
    id: root

    required property RuntimeConfig runtime
    required property Theme theme

    property string title: ""
    property string detail: ""
    default property alias contentData: body.data

    width: parent ? parent.width : implicitWidth
    spacing: theme.spacing3

    Row {
        width: parent.width
        height: Math.max(titleText.implicitHeight, detailText.implicitHeight)
        spacing: root.theme.spacing2

        Rectangle {
            id: sectionMark
            width: 4
            height: 17
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: root.theme.accent
        }

        ShellText {
            id: titleText
            anchors.verticalCenter: parent.verticalCenter
            runtime: root.runtime
            theme: root.theme
            text: root.title
            color: theme.textStrong
            font.pixelSize: theme.fontSize(13)
            font.weight: Font.DemiBold
        }

        Item {
            width: Math.max(0, parent.width - sectionMark.width - titleText.implicitWidth - detailText.width - parent.spacing * 3)
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
            font.pixelSize: theme.fontSize(10)
        }
    }

    Column {
        id: body
        width: parent.width
        spacing: root.theme.spacing2
    }
}
