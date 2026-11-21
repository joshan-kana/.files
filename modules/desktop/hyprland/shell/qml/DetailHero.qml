pragma ComponentBehavior: Bound
import QtQuick

// Shared, data-driven feature header for detailed shell surfaces.
// Text always uses the configured mono face; tonal colours come from Theme.
ShellSurface {
    id: hero

    required property RuntimeConfig runtime

    // Quiet variant for detail views that need orientation without a hero banner.
    property bool quiet: true
    property string eyebrow: ""
    property string title: ""
    property string detail: ""
    property string glyph: "◇"
    property string glyphFont: runtime.fontMono
    property color glyphColor: theme.accent

    implicitHeight: quiet ? 66 : 126
    surfaceLayer: ShellSurface.Group
    luminous: !quiet
    luminousColor: hero.glyphColor
    fillColor: quiet ? "transparent" : theme.blend(theme.groupBase, hero.glyphColor, theme.dark ? 0.12 : 0.07)
    borderWidth: quiet ? 0 : theme.borderThin
    cornerRadius: theme.radiusLarge
    clip: true

    // Large state-derived glyph provides a clear identity without introducing
    // an extra illustration or independent backend for each detail panel.
    Text {
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: hero.theme.spacing4
            bottomMargin: -hero.theme.spacing4
        }
        text: hero.glyph
        color: hero.glyphColor
        opacity: 0.11
        font.family: hero.glyphFont
        font.pixelSize: hero.theme.fontSize(98)
        visible: !hero.quiet && hero.glyph.length > 0
    }

    ShellSurface {
        id: iconTile
        visible: !hero.quiet
        width: 68
        height: 68
        anchors {
            left: parent.left
            leftMargin: hero.theme.spacing4
            verticalCenter: parent.verticalCenter
        }
        theme: hero.theme
        motion: hero.motion
        surfaceLayer: ShellSurface.Control
        cornerRadius: hero.theme.radiusMedium
        fillColor: Qt.rgba(hero.glyphColor.r, hero.glyphColor.g, hero.glyphColor.b, 0.19)

        Text {
            anchors.centerIn: parent
            text: hero.glyph
            color: hero.glyphColor
            font.family: hero.glyphFont
            font.pixelSize: hero.theme.fontSize(35)
        }
    }

    Text {
        id: quietGlyph
        visible: hero.quiet
        width: hero.theme.fontSize(26)
        anchors {
            left: parent.left
            leftMargin: hero.theme.spacing4 + hero.theme.spacing2
            verticalCenter: parent.verticalCenter
        }
        text: hero.glyph
        color: hero.glyphColor
        font.family: hero.glyphFont
        font.pixelSize: hero.theme.fontSize(25)
    }

    Column {
        anchors {
            left: hero.quiet ? quietGlyph.right : iconTile.right
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: hero.quiet ? hero.theme.spacing2 : hero.theme.spacing4
            rightMargin: hero.quiet ? 0 : hero.theme.spacing4
        }
        spacing: hero.quiet ? hero.theme.spacing1 : hero.theme.spacing2

        ShellText {
            width: parent.width
            runtime: hero.runtime
            theme: hero.theme
            visible: !hero.quiet
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
            font.pixelSize: hero.quiet ? hero.theme.fontSize(18) : hero.theme.fontSubpanelTitle
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
