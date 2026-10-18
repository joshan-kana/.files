pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: gauge
    required property Theme theme
    required property Motion motion
    property real value: 0
    // Keep the ring geometry, but do not manufacture "0%" before a first
    // authoritative sample is available.
    property bool known: true
    property color accentColor: theme.accent
    property string label: ""
    property bool compact: false
    property bool compactRingTuning: false
    property string compactIcon: "󰁹"
    property int compactIconSize: 14
    property real compactIconOffsetX: 0
    property real compactIconOffsetY: 0
    property real animatedValue: Math.max(0, Math.min(1, value))

    implicitWidth: compact ? 34 : 126
    implicitHeight: compact ? 34 : 126

    onAnimatedValueChanged: face.requestPaint()
    onKnownChanged: face.requestPaint()
    onAccentColorChanged: face.requestPaint()
    onCompactChanged: face.requestPaint()

    Behavior on animatedValue {
        Anim {
            motion: gauge.motion
            type: Anim.DefaultSpatial
        }
    }

    Canvas {
        id: face
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            // Keep the standard gauge unchanged. The volume indicator alone
            // uses an adjusted arc to correct its optical baseline.
            const radius = Math.max(1, Math.min(width, height) / 2 - (gauge.compact ? (gauge.compactRingTuning ? 5 : 4) : 12));
            const start = Math.PI * (gauge.compactRingTuning ? 0.8 : 0.75);
            const sweep = Math.PI * (gauge.compactRingTuning ? 1.4 : 1.5);
            ctx.lineWidth = gauge.compact ? 3 : 9;
            ctx.lineCap = "round";
            ctx.beginPath();
            ctx.strokeStyle = gauge.theme.layer3;
            ctx.arc(width / 2, height / 2, radius, start, start + sweep);
            ctx.stroke();
            ctx.beginPath();
            ctx.strokeStyle = gauge.accentColor;
            ctx.arc(width / 2, height / 2, radius, start, start + sweep * (gauge.known ? gauge.animatedValue : 0));
            ctx.stroke();
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 2
        visible: !gauge.compact
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: gauge.known ? Math.round(gauge.animatedValue * 100) + "%" : "··"
            color: gauge.accentColor
            font.family: gauge.theme.runtime.fontMono
            font.pixelSize: gauge.theme.fontSize(24)
            font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: gauge.label
            color: gauge.theme.textMuted
            font.family: gauge.theme.runtime.fontMono
            font.pixelSize: gauge.theme.fontSize(10)
        }
    }
    // Centring a full-height Text item positions its font box, not its ink.
    // The speaker glyph has asymmetric bearings, so use its painted bounds
    // to centre it independently of the battery's existing presentation.
    TextMetrics {
        id: compactInk
        font.family: "Symbols Nerd Font"
        font.pixelSize: gauge.theme.fontSize(gauge.compactIconSize)
        text: gauge.compactIcon
    }

    FontMetrics {
        id: compactFont
        font: compactInk.font
    }

    Text {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: gauge.compactRingTuning ? compactInk.advanceWidth / 2 - compactInk.tightBoundingRect.x - compactInk.tightBoundingRect.width / 2 : gauge.compactIconOffsetX
        anchors.verticalCenterOffset: gauge.compactRingTuning ? compactFont.height / 2 - compactFont.ascent - compactInk.tightBoundingRect.y - compactInk.tightBoundingRect.height / 2 : gauge.compactIconOffsetY
        visible: gauge.compact
        text: gauge.compactIcon
        color: gauge.accentColor
        font.family: "Symbols Nerd Font"
        font.pixelSize: gauge.theme.fontSize(gauge.compactIconSize)
    }
}
