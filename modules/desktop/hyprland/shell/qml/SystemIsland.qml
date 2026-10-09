pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Item {
    id: island

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property SystemState system

    signal activated
    signal trayMenuRequested(int index)

    // NetworkManager already has a native status indicator here; retain the
    // complete application tray exclusively in the Controls hub.
    readonly property var barTrayItems: system.trayItems.map((item, index) => ({
                item: item,
                index: index
            })).filter(entry => {
        const identity = String(entry.item.id || "") + " " + String(entry.item.title || "");
        return !/network-manager-applet|nm-applet|networkmanager|plasma-nm/i.test(identity);
    })

    implicitWidth: statusRow.implicitWidth + theme.spacing4 * 2
    implicitHeight: 40

    ShellSurface {
        anchors.fill: parent
        theme: island.theme
        motion: island.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: theme.radiusMedium

        Row {
            id: statusRow
            z: 1
            anchors.centerIn: parent
            spacing: island.theme.spacing3

            Row {
                id: volumeStatus
                spacing: island.theme.spacing1
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: island.system.muted ? "󰖁" : island.system.volumePercent < 35 ? "󰕿" : "󰕾"
                    color: island.system.muted ? island.theme.warning : island.theme.accent
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: island.theme.fontSize(15)
                }

                Text {
                    text: island.system.muted ? "MUTE" : island.system.volumePercent + "%"
                    color: island.system.muted ? island.theme.warning : island.theme.textStrong
                    font.family: island.runtime.fontMono
                    font.pixelSize: island.theme.fontSize(11)
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                visible: island.system.idleInhibited
                anchors.verticalCenter: parent.verticalCenter
                text: "󰅶"
                color: island.theme.positive
                font.family: "Symbols Nerd Font"
                font.pixelSize: island.theme.fontSize(15)
            }

            // end-4's contextual muted-input indicator, sharing the same PipeWire state.
            Text {
                visible: island.system.microphoneMuted
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍭"
                color: island.theme.warning
                font.family: "Symbols Nerd Font"
                font.pixelSize: island.theme.fontSize(16)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: island.system.networkConnected ? (island.system.wifiConnected ? "󰤨" : "󰈀") : "󰖪"
                color: island.system.networkConnected ? island.theme.accent : island.theme.critical
                font.family: "Symbols Nerd Font"
                font.pixelSize: island.theme.fontSize(17)
            }

            Row {
                visible: island.system.bluetoothAvailable
                anchors.verticalCenter: parent.verticalCenter
                spacing: island.theme.spacing1

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: island.system.bluetoothEnabled ? "󰂯" : "󰂲"
                    color: island.system.bluetoothConnectedCount > 0 ? island.theme.accent : island.theme.textMuted
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: island.theme.fontSize(15)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: island.system.bluetoothConnectedCount > 0
                    text: island.system.bluetoothConnectedCount
                    color: island.theme.textStrong
                    font.family: island.runtime.fontMono
                    font.pixelSize: island.theme.fontSize(10)
                }
            }

            // end-4-style direct app indicators. The existing Control Centre
            // remains the sole owner of tray menus and their keyboard handling.
            Row {
                visible: island.barTrayItems.length > 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: island.theme.spacing1

                Repeater {
                    model: island.barTrayItems.slice(0, 4)

                    delegate: Item {
                        id: trayButton
                        required property var modelData
                        required property int index
                        readonly property var trayEntry: modelData.item
                        width: 23
                        height: 23

                        ShellSurface {
                            anchors.fill: parent
                            theme: island.theme
                            motion: island.motion
                            surfaceLayer: ShellSurface.Control
                            cornerRadius: island.theme.radiusSmall
                            opacity: trayPointer.containsMouse ? 1 : 0
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            source: trayButton.trayEntry.icon && trayButton.trayEntry.icon.length > 0 ? trayButton.trayEntry.icon : Quickshell.iconPath("application-x-executable")
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }

                        MouseArea {
                            id: trayPointer
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: event => {
                                if (event.button === Qt.RightButton) {
                                    if (trayButton.trayEntry.hasMenu)
                                        island.trayMenuRequested(trayButton.modelData.index);
                                    else
                                        trayButton.trayEntry.secondaryActivate();
                                } else if (trayButton.trayEntry.hasMenu || trayButton.trayEntry.onlyMenu) {
                                    island.trayMenuRequested(trayButton.modelData.index);
                                } else {
                                    trayButton.trayEntry.activate();
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: island.barTrayItems.length > 4
                    text: "+" + (island.barTrayItems.length - 4)
                    color: island.theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: island.runtime.fontMono
                    font.pixelSize: island.theme.fontSize(10)
                    font.weight: Font.DemiBold
                }
            }

            Row {
                visible: island.system.batteryAvailable
                anchors.verticalCenter: parent.verticalCenter
                spacing: island.theme.spacing1

                Text {
                    text: island.system.batteryPercent <= 20 ? "󰁺" : island.system.batteryPercent < 65 ? "󰁾" : "󰁹"
                    anchors.verticalCenter: parent.verticalCenter
                    color: island.system.batteryPercent <= 20 ? island.theme.warning : island.theme.accent
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: island.theme.fontSize(16)
                }

                Text {
                    text: island.system.batteryPercent + "%"
                    anchors.verticalCenter: parent.verticalCenter
                    color: island.system.batteryPercent <= 20 ? island.theme.warning : island.theme.textStrong
                    font.family: island.runtime.fontMono
                    font.pixelSize: island.theme.fontSize(11)
                    font.weight: Font.DemiBold
                }
            }
        }

        StateLayer {
            theme: island.theme
            motion: island.motion
            cornerRadius: island.theme.radiusMedium
            onActivated: island.activated()
            onWheel: event => {
                if (event.angleDelta.y !== 0 && island.system.audioAvailable) {
                    island.system.adjustVolume((event.angleDelta.y > 0 ? 1 : -1) * 0.05);
                    event.accepted = true;
                }
            }
        }
    }
}
