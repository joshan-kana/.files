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

    Column {
        anchors.centerIn: parent
        width: parent.width - root.theme.spacing5 * 2
        spacing: root.theme.spacing4
        visible: root.active
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "LOCAL · SYNCHRONISED LYRICS"
            color: root.theme.accent
            font.family: root.runtime.fontMono
            font.pixelSize: root.theme.fontSize(9)
            font.weight: Font.DemiBold
            font.letterSpacing: 1.3
        }
        Repeater {
            model: root.hasLyrics ? 3 : 1
            delegate: Text {
                required property int index
                width: parent.width
                readonly property int lyricIndex: root.currentLine + index - 1
                readonly property bool current: index === 1 && root.currentLine >= 0
                text: !root.hasLyrics ? (root.media.lyricsPath.length > 0 ? "No synced lyrics found · Add a .lrc beside this track" : "No local track · Lyrics are never fetched online") : lyricIndex >= 0 && lyricIndex < root.lines.length ? root.lines[lyricIndex].words : " "
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: current ? root.theme.textStrong : root.theme.textMuted
                opacity: current ? 1 : 0.65
                font.family: root.runtime.fontMono
                font.pixelSize: root.theme.fontSize(current ? 17 : 11)
                font.weight: current ? Font.DemiBold : Font.Normal
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Y  SPECTRUM / LYRICS  ·  LOCAL FILES ONLY"
            color: root.theme.textMuted
            font.family: root.runtime.fontMono
            font.pixelSize: root.theme.fontSize(9)
        }
    }
}
