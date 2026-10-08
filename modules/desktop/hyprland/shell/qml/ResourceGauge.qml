pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: gauge
    required property Theme theme
    required property Motion motion
    property real value: 0
    property color accentColor: theme.accent
    property string label: ""
    property real animatedValue: Math.max(0, Math.min(1, value))

    implicitWidth: 126
    implicitHeight: 126

    onAnimatedValueChanged: face.requestPaint()
    onAccentColorChanged: face.requestPaint()

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
            const radius = Math.min(width, height) / 2 - 12;
            const start = Math.PI * 0.75;
            const sweep = Math.PI * 1.5;
            ctx.lineWidth = 9;
            ctx.lineCap = "round";
            ctx.beginPath();
            ctx.strokeStyle = gauge.theme.layer3;
            ctx.arc(width / 2, height / 2, radius, start, start + sweep);
            ctx.stroke();
            ctx.beginPath();
            ctx.strokeStyle = gauge.accentColor;
            ctx.arc(width / 2, height / 2, radius, start, start + sweep * gauge.animatedValue);
            ctx.stroke();
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 2
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(gauge.animatedValue * 100) + "%"
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
}
