pragma ComponentBehavior: Bound
import QtQuick

// Content-first preview shared by Theme and Wallpaper galleries. A featured
// appearance is useful; another title-only banner is not.
ShellSurface {
    id: preview

    required property RuntimeConfig runtime
    property string mode: "theme"
    property var previewPalette: null
    property string imagePath: ""
    property string selectionName: ""
    property string context: ""

    readonly property var swatches: previewPalette && previewPalette.swatches ? previewPalette.swatches : []
    readonly property color sampleBackground: previewPalette ? previewPalette.background : theme.background
    readonly property color sampleSurface: previewPalette ? previewPalette.surface : theme.surface
    readonly property color sampleText: previewPalette ? previewPalette.text : theme.textStrong
    readonly property color sampleAccent: swatches.length > 0 ? swatches[0] : theme.accent

    surfaceLayer: ShellSurface.Group
    fillColor: mode === "theme" ? sampleBackground : theme.groupBase
    cornerRadius: theme.radiusLarge
    clip: true

    Item {
        anchors.fill: parent
        visible: preview.mode === "theme"

        Rectangle {
            width: parent.width
            height: 30
            color: preview.sampleSurface

            Row {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 14
                }
                spacing: 6
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        required property int index
                        width: 8
                        height: 8
                        radius: 4
                        color: preview.swatches.length > index ? preview.swatches[index] : preview.sampleAccent
                    }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 64
                height: 6
                radius: 3
                color: preview.sampleText
                opacity: 0.3
            }
        }

        Row {
            anchors {
                fill: parent
                topMargin: 43
                bottomMargin: 38
                leftMargin: 14
                rightMargin: 14
            }
            spacing: 11

            Rectangle {
                width: parent.width * 0.61
                height: parent.height
                radius: 12
                color: preview.sampleSurface

                Column {
                    anchors {
                        fill: parent
                        margins: 11
                    }
                    spacing: 6
                    Text {
                        text: "Ag  12:34"
                        color: preview.sampleText
                        font.family: preview.runtime.fontMono
                        font.pixelSize: preview.theme.fontSize(19)
                        font.weight: Font.DemiBold
                    }
                    Rectangle {
                        width: parent.width * 0.83
                        height: 5
                        radius: 3
                        color: preview.sampleText
                        opacity: 0.42
                    }
                    Rectangle {
                        width: parent.width * 0.58
                        height: 5
                        radius: 3
                        color: preview.sampleText
                        opacity: 0.21
                    }
                }
                Rectangle {
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        margins: 11
                    }
                    width: 48
                    height: 8
                    radius: 4
                    color: preview.sampleAccent
                }
            }

            Column {
                width: Math.max(32, parent.width - parent.children[0].width - parent.spacing)
                spacing: 9
                Repeater {
                    model: 3
                    delegate: Row {
                        id: metric
                        required property int index
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: 10
                            height: 10
                            radius: 5
                            color: preview.swatches.length > metric.index + 1 ? preview.swatches[metric.index + 1] : preview.sampleAccent
                        }
                        Rectangle {
                            width: Math.max(4, metric.width - 24 - metric.index * 11)
                            height: 7
                            radius: 4
                            color: preview.sampleText
                            opacity: 0.42 - metric.index * 0.08
                        }
                    }
                }
            }
        }

        Row {
            anchors {
                left: parent.left
                bottom: parent.bottom
                margins: 12
            }
            spacing: 5
            Repeater {
                model: preview.swatches
                delegate: Rectangle {
                    required property var modelData
                    width: 26
                    height: 5
                    radius: 3
                    color: modelData
                }
            }
        }
    }

    Image {
        anchors.fill: parent
        visible: preview.mode === "wallpaper"
        source: preview.imagePath.length > 0 ? "file://" + preview.imagePath : ""
        sourceSize: Qt.size(900, 500)
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        height: preview.mode === "wallpaper" ? 55 : 31
        color: preview.mode === "wallpaper" ? Qt.rgba(0, 0, 0, 0.68) : preview.sampleSurface
        opacity: preview.mode === "wallpaper" ? 0.87 : 0.96
    }

    Row {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: 12
        }
        spacing: 10

        Text {
            width: Math.max(1, parent.width - contextText.width - parent.spacing)
            text: preview.selectionName
            color: preview.mode === "wallpaper" ? "white" : preview.sampleText
            font.family: preview.runtime.fontMono
            font.pixelSize: preview.theme.fontSize(12)
            font.weight: Font.DemiBold
            elide: Text.ElideMiddle
        }

        Text {
            id: contextText
            text: preview.context
            color: preview.mode === "wallpaper" ? "#e0e0e0" : preview.sampleText
            opacity: 0.72
            font.family: preview.runtime.fontMono
            font.pixelSize: preview.theme.fontSize(10)
        }
    }
}
