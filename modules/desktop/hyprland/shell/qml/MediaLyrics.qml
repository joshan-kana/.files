pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "Lyrics.js" as Lyrics

Item {
    id: root
    required property MediaState media
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property bool active: false
    property var lines: []
    readonly property int currentLine: Lyrics.currentIndex(lines, media.position)
    readonly property bool hasLyrics: lines.length > 0
    readonly property int rowHeight: Math.max(56, theme.fontSize(17) * 3)
    property int previousLine: -1

    FileView {
        id: sidecar
        // Only read a local media-side .lrc file while the user requests it.
        path: root.active ? root.media.lyricsPath : ""
        blockLoading: false
        onLoadedChanged: {
            if (loaded)
                root.lines = Lyrics.parse(text());
        }
        onPathChanged: root.lines = []
        onFileChanged: reload()
    }

    onCurrentLineChanged: {
        // Normal progression uses the ListView's built-in highlight motion.
        // On an initial load or a long seek, jump straight to the new verse
        // instead of animating through dozens of unrelated lines.
        if (active && hasLyrics && (previousLine < 0 || Math.abs(currentLine - previousLine) > 3)) {
            Qt.callLater(() => {
                if (root.active && root.hasLyrics && root.currentLine >= 0)
                    lyricList.positionViewAtIndex(root.currentLine, ListView.Center);
            });
        }
        previousLine = currentLine;
    }

    Column {
        anchors.fill: parent
        anchors.margins: root.theme.spacing3
        spacing: root.theme.spacing2
        visible: root.active

        Item {
            width: parent.width
            height: parent.height
            clip: true

            ListView {
                id: lyricList
                anchors.fill: parent
                clip: true
                interactive: false
                focus: false
                model: root.active && root.hasLyrics ? root.lines : []
                currentIndex: root.currentLine
                spacing: root.theme.spacing2
                reuseItems: true
                // Keep the current lyric centered as the actual list glides
                // through its neighbours. Reused delegates stay inexpensive
                // even for long LRC files.
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: Math.max(0, (height - root.rowHeight) / 2)
                preferredHighlightEnd: preferredHighlightBegin + root.rowHeight
                highlightMoveVelocity: -1
                highlightMoveDuration: root.motion.spatialNormal

                delegate: Item {
                    id: lineRow
                    required property int index
                    required property var modelData
                    readonly property bool current: index === root.currentLine
                    width: lyricList.width
                    height: root.rowHeight
                    opacity: current ? 1 : 0.55
                    scale: current ? 1 : 0.86

                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.motion.contentFade
                            easing.type: root.motion.enterType
                            easing.bezierCurve: root.motion.enterCurve
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: root.motion.spatialNormal
                            easing.type: root.motion.spatialType
                            easing.bezierCurve: root.motion.spatialCurve
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width
                        text: lineRow.modelData.words
                        textFormat: Text.PlainText
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        color: lineRow.current ? root.theme.textStrong : root.theme.textMuted
                        font.family: root.runtime.fontMono
                        font.pixelSize: root.theme.fontSize(17)
                        font.weight: lineRow.current ? Font.DemiBold : Font.Normal
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width
                visible: !root.hasLyrics
                text: root.media.lyricsPath.length > 0 ? "No synced lyrics found · Add a .lrc beside this track" : "No local track · Lyrics are never fetched online"
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: root.theme.textMuted
                font.family: root.runtime.fontMono
                font.pixelSize: root.theme.fontSize(12)
            }
        }
    }
}
