pragma ComponentBehavior: Bound
import QtQuick

// Shared, data-driven feature header for detailed shell surfaces.
// Text always uses the configured mono face; tonal colours come from Theme.
ShellSurface {
    id: hero

    required property RuntimeConfig runtime

    property string eyebrow: ""
    property string title: ""
    property string detail: ""
    property string glyph: "◇"
    property color glyphColor: theme.accent
    property bool emphasized: false

    implicitHeight: 126
    surfaceLayer: ShellSurface.Group
    cornerRadius: theme.radiusLarge

    ShellSurface {
        id: iconTile
        width: 74
        height: 74
        anchors {
            left: parent.left
            leftMargin: hero.theme.spacing4
            verticalCenter: parent.verticalCenter
        }
        theme: hero.theme
        motion: hero.motion
        surfaceLayer: ShellSurface.Control
        cornerRadius: hero.theme.radiusMedium
        fillColor: Qt.rgba(hero.glyphColor.r, hero.glyphColor.g, hero.glyphColor.b, 0.17)

        Text {
            anchors.centerIn: parent
            text: hero.glyph
            color: hero.glyphColor
            font.family: hero.runtime.fontMono
            font.pixelSize: hero.theme.fontSize(35)
        }
    }

    Column {
        anchors {
            left: iconTile.right
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: hero.theme.spacing4
            rightMargin: hero.theme.spacing4
        }
        spacing: hero.theme.spacing2

        ShellText {
            width: parent.width
            runtime: hero.runtime
            theme: hero.theme
            text: hero.eyebrow.toUpperCase()
            color: hero.glyphColor
            font.pixelSize: hero.theme.fontPanelEyebrow
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        ShellText {
            width: parent.width
            runtime: hero.runtime
            theme: hero.theme
            text: hero.title
            color: hero.theme.textStrong
            font.pixelSize: hero.theme.fontSubpanelTitle
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        ShellText {
            width: parent.width
            runtime: hero.runtime
            theme: hero.theme
            text: hero.detail
            color: hero.theme.textMuted
            font.pixelSize: hero.theme.fontSize(10)
            elide: Text.ElideRight
        }
    }
}
