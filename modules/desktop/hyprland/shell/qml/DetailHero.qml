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

    implicitHeight: 126
    surfaceLayer: ShellSurface.Group
    luminous: true
    luminousColor: hero.glyphColor
    fillColor: theme.blend(theme.groupBase, hero.glyphColor, theme.dark ? 0.12 : 0.07)
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
        font.family: hero.runtime.fontMono
        font.pixelSize: hero.theme.fontSize(98)
        visible: hero.glyph.length > 0
    }

    ShellSurface {
        id: iconTile
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
