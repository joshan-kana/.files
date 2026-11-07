pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Pipewire

// Actual per-channel signal peaks, independent of volume slider settings.
// A monitor exists only while its owning audio surface is in use.
Item {
    id: meter
    required property Theme theme
    property var node: null
    property bool monitoring: true
    property bool muted: false
    property bool showLabels: true

    implicitWidth: 160
    implicitHeight: showLabels ? 31 : 16

    PwNodePeakMonitor {
        id: monitor
        node: meter.node
        enabled: meter.monitoring && meter.visible && meter.node !== null
    }

    Row {
        anchors.fill: parent
        spacing: meter.theme.spacing1

        Repeater {
            model: Math.max(1, monitor.peaks.length)

            delegate: Column {
                id: channelRow
                required property int index
                width: (meter.width - meter.theme.spacing1 * (Math.max(1, monitor.peaks.length) - 1)) / Math.max(1, monitor.peaks.length)
                height: meter.height
                spacing: 3

                readonly property real amplitude: Math.max(0, Math.min(1, monitor.peaks[index] || 0))
                // Native peaks arrive at PipeWire's buffer cadence, not at
                // the display's frame cadence. Interpolate only the rendered
                // width, with a quicker rise so kick transients remain sharp.
                property real displayedAmplitude: amplitude
                Behavior on displayedAmplitude {
                    enabled: meter.monitoring && meter.visible
                    NumberAnimation {
                        duration: channelRow.amplitude > channelRow.displayedAmplitude ? 48 : 78
                        easing.type: Easing.OutCubic
                    }
                }
                readonly property var channel: monitor.channels[index]

                Text {
                    visible: meter.showLabels
                    width: parent.width
                    height: meter.showLabels ? 11 : 0
                    horizontalAlignment: Text.AlignHCenter
                    color: meter.theme.textMuted
                    font.family: meter.theme.runtime.fontMono
                    font.pixelSize: meter.theme.fontSize(9)
                    text: {
                        if (monitor.peaks.length === 0)
                            return "—";
                        if (channelRow.channel === PwAudioChannel.FrontLeft)
                            return "L";
                        if (channelRow.channel === PwAudioChannel.FrontRight)
                            return "R";
                        if (channelRow.channel === PwAudioChannel.Mono)
                            return "M";
                        if (channelRow.channel === PwAudioChannel.FrontCenter)
                            return "C";
                        if (channelRow.channel === PwAudioChannel.LowFrequencyEffects)
                            return "LFE";
                        return PwAudioChannel.toString(channelRow.channel).replace("Front", "").replace("Side", "S").replace("Rear", "R");
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Math.max(4, parent.height - (meter.showLabels ? 14 : 0))
                    radius: height / 2
                    color: meter.theme.layer1

                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        radius: parent.radius
                        width: parent.width * (meter.muted ? 0 : channelRow.displayedAmplitude)
                        color: meter.muted ? meter.theme.warning : channelRow.amplitude > 0.9 ? meter.theme.critical : channelRow.amplitude > 0.72 ? meter.theme.warning : meter.theme.positive
                    }
                }
            }
        }
    }
}
