import QtQuick
import Quickshell
import Quickshell.Bluetooth

Item {
    id: panel

    required property QtObject system
    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

    signal keyboardRequested

    property bool open: false
    property int selectedIndex: 0
    property bool startedDiscovery: false
    property string forgetAddress: ""
    property string statusText: ""
    property bool statusError: false

    readonly property var adapter: system.bluetoothAdapter
    readonly property var devices: system.bluetoothAdapterDevices || []
    readonly property bool adapterAvailable: system.bluetoothAvailable

    visible: open

    Timer {
        id: forgetTimer
        interval: 5000
        repeat: false

        onTriggered: {
            panel.forgetAddress = "";
            panel.statusText = "";
            panel.statusError = false;
        }
    }

    function selectedDevice(): var {
        if (devices.length === 0)
            return null;

        return devices[Math.max(0, Math.min(selectedIndex, devices.length - 1))];
    }

    function selectedDeviceIndex(): int {
        for (let index = 0; index < devices.length; index++) {
            if (devices[index].connected)
                return index;
        }

        for (let index = 0; index < devices.length; index++) {
            if (devices[index].paired)
                return index;
        }

        return 0;
    }

    function displayName(device): string {
        if (!device)
            return "";

        return device.name || device.deviceName || device.address || "Bluetooth device";
    }

    function clearTransientState(): void {
        forgetTimer.stop();
        forgetAddress = "";
        statusText = "";
        statusError = false;
    }

    function openView(): void {
        open = true;
        clearTransientState();
        selectedIndex = selectedDeviceIndex();

        startedDiscovery = adapterAvailable && adapter.enabled && !adapter.discovering;

        if (startedDiscovery)
            system.setBluetoothDiscovering(true);

        keyboardRequested();
    }

    function closeView(): void {
        if (startedDiscovery && adapterAvailable && adapter.discovering) {
            system.setBluetoothDiscovering(false);
        }

        startedDiscovery = false;
        clearTransientState();
        open = false;
        keyboardRequested();
    }

    function moveSelection(delta: int): void {
        if (devices.length === 0)
            return;

        selectedIndex = Math.max(0, Math.min(devices.length - 1, selectedIndex + delta));
        clearTransientState();
    }

    function toggleBluetooth(): void {
        if (!adapterAvailable)
            return;

        const enabling = !adapter.enabled;
        system.setBluetoothEnabled(enabling);
        statusText = enabling ? "ENABLING BLUETOOTH" : "DISABLING BLUETOOTH";
        statusError = false;

        if (!enabling)
            startedDiscovery = false;
    }

    function toggleDiscovery(): void {
        if (!adapterAvailable || !adapter.enabled)
            return;

        const discovering = !adapter.discovering;
        system.setBluetoothDiscovering(discovering);
        startedDiscovery = discovering;
        statusText = discovering ? "DISCOVERY ACTIVE" : "DISCOVERY STOPPED";
        statusError = false;
    }

    function activateSelected(): void {
        const device = selectedDevice();
        if (!device)
            return;

        clearTransientState();

        if (device.pairing) {
            device.cancelPair();
            statusText = "PAIRING CANCELLED // " + displayName(device);
            return;
        }

        if (!device.paired) {
            statusText = "PAIR FIRST // PRESS P";
            statusError = true;
            return;
        }

        if (device.connected) {
            statusText = "DISCONNECTING // " + displayName(device);
            device.disconnect();
        } else {
            statusText = "CONNECTING // " + displayName(device);
            device.connect();
        }
    }

    function pairSelected(): void {
        const device = selectedDevice();
        if (!device)
            return;

        clearTransientState();

        if (device.pairing) {
            device.cancelPair();
            statusText = "PAIRING CANCELLED // " + displayName(device);
            return;
        }

        if (device.paired) {
            statusText = "ALREADY PAIRED // " + displayName(device);
            return;
        }

        statusText = "PAIRING AGENT // " + displayName(device);
        Quickshell.execDetached([runtime.terminal, "-e", runtime.bluetoothctl, "--agent", "KeyboardDisplay", "pair", device.address]);
    }

    function toggleTrust(): void {
        const device = selectedDevice();
        if (!device || !device.paired)
            return;

        device.trusted = !device.trusted;
        statusText = (device.trusted ? "TRUSTED // " : "UNTRUSTED // ") + displayName(device);
        statusError = false;
    }

    function forgetSelected(): void {
        const device = selectedDevice();
        if (!device || !device.paired)
            return;

        if (forgetAddress === device.address) {
            forgetTimer.stop();
            forgetAddress = "";
            statusText = "FORGETTING // " + displayName(device);
            statusError = false;
            device.forget();
            return;
        }

        forgetAddress = device.address;
        statusText = "CONFIRM FORGET // PRESS F AGAIN";
        statusError = false;
        forgetTimer.restart();
    }

    onDevicesChanged: {
        selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, devices.length - 1)));
    }

    Column {
        id: header

        width: parent.width
        spacing: theme.spacing1

        Text {
            text: "BLUETOOTH // " + (adapterAvailable ? BluetoothAdapterState.toString(adapter.state).toUpperCase() : "NO ADAPTER")
            color: adapterAvailable && adapter.enabled ? theme.positive : theme.warning
            font.family: runtime.fontMono
            font.pixelSize: theme.fontSubpanelEyebrow
            font.weight: Font.DemiBold
            font.letterSpacing: 1.6
        }

        Text {
            text: adapterAvailable ? (adapter.name || adapter.adapterId || "Bluetooth") : "Bluetooth"
            color: theme.textStrong
            font.family: runtime.fontSans
            font.pixelSize: theme.fontSubpanelTitle
            font.weight: Font.DemiBold
        }

        Row {
            width: parent.width
            spacing: theme.spacing3

            Text {
                visible: adapterAvailable
                text: system.bluetoothEnabled ? "RADIO ON" : "RADIO OFF"
                color: system.bluetoothEnabled ? theme.accent : theme.critical
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(9)
            }

            Text {
                visible: adapterAvailable && system.bluetoothEnabled
                text: system.bluetoothDiscovering ? "SCANNING" : "SCAN IDLE"
                color: system.bluetoothDiscovering ? theme.positive : theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(9)
            }

            Text {
                visible: adapterAvailable
                text: system.bluetoothConnectedCount + " CONNECTED"
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(9)
            }
        }
    }

    Item {
        anchors {
            top: header.bottom
            right: parent.right
            bottom: footer.top
            left: parent.left
            topMargin: theme.spacing4
            bottomMargin: theme.spacing3
        }

        ListView {
            id: deviceList

            anchors.fill: parent
            visible: adapterAvailable && adapter.enabled
            model: panel.devices
            spacing: theme.spacing2
            clip: true
            currentIndex: panel.selectedIndex
            boundsBehavior: Flickable.StopAtBounds

            delegate: SquircleSurface {
                id: deviceRow

                required property var modelData
                required property int index

                width: ListView.view.width
                height: 72
                exponent: theme.squircleExponent
                cornerRadius: theme.radiusMedium
                fillColor: index === panel.selectedIndex ? theme.focusFill : theme.background
                borderColor: modelData.connected ? theme.positive : (index === panel.selectedIndex ? theme.accent : theme.outline)
                borderWidth: index === panel.selectedIndex ? theme.borderFocus : theme.borderThin

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        panel.selectedIndex = deviceRow.index;
                        panel.keyboardRequested();
                    }

                    onDoubleClicked: {
                        panel.selectedIndex = deviceRow.index;
                        panel.activateSelected();
                        panel.keyboardRequested();
                    }
                }

                Row {
                    anchors {
                        fill: parent
                        margins: theme.spacing3
                    }
                    spacing: theme.spacing3

                    Column {
                        width: parent.width - 126
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: theme.spacing1

                        Text {
                            width: parent.width
                            text: panel.displayName(modelData)
                            color: theme.textStrong
                            font.family: runtime.fontSans
                            font.pixelSize: theme.fontSize(13)
                            font.weight: modelData.connected ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: modelData.address
                            color: theme.textMuted
                            font.family: runtime.fontMono
                            font.pixelSize: theme.fontSize(8)
                            elide: Text.ElideRight
                        }

                        Row {
                            spacing: theme.spacing2

                            Text {
                                text: BluetoothDeviceState.toString(modelData.state).toUpperCase()
                                color: modelData.connected ? theme.positive : theme.textMuted
                                font.family: runtime.fontMono
                                font.pixelSize: theme.fontSize(8)
                                font.weight: Font.DemiBold
                            }

                            Text {
                                text: modelData.pairing ? "PAIRING" : (modelData.paired ? "PAIRED" : "UNPAIRED")
                                color: modelData.paired || modelData.pairing ? theme.accent : theme.warning
                                font.family: runtime.fontMono
                                font.pixelSize: theme.fontSize(8)
                                font.weight: Font.DemiBold
                            }

                            Text {
                                visible: modelData.trusted
                                text: "TRUSTED"
                                color: theme.accent
                                font.family: runtime.fontMono
                                font.pixelSize: theme.fontSize(8)
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Column {
                        width: 114
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: theme.spacing1

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignRight
                            text: modelData.pairing ? "P  CANCEL" : (!modelData.paired ? "P  PAIR" : (modelData.connected ? "ENTER  DROP" : "ENTER  LINK"))
                            color: modelData.pairing || !modelData.paired ? theme.warning : theme.accent
                            font.family: runtime.fontMono
                            font.pixelSize: theme.fontSize(8)
                            font.weight: Font.DemiBold
                        }

                        Text {
                            width: parent.width
                            visible: modelData.batteryAvailable
                            horizontalAlignment: Text.AlignRight
                            text: "BAT " + Math.round(modelData.battery * 100) + "%"
                            color: modelData.battery <= 0.20 ? theme.warning : theme.textMuted
                            font.family: runtime.fontMono
                            font.pixelSize: theme.fontSize(8)
                        }
                    }
                }
            }

            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        }

        Text {
            anchors.centerIn: parent
            visible: !adapterAvailable
            width: parent.width
            text: "NO BLUETOOTH ADAPTER"
            horizontalAlignment: Text.AlignHCenter
            color: theme.textMuted
            font.family: runtime.fontMono
            font.pixelSize: theme.fontSize(10)
            font.letterSpacing: 0.8
        }

        Text {
            anchors.centerIn: parent
            visible: adapterAvailable && !system.bluetoothEnabled
            width: parent.width
            text: "BLUETOOTH DISABLED // PRESS B"
            horizontalAlignment: Text.AlignHCenter
            color: theme.warning
            font.family: runtime.fontMono
            font.pixelSize: theme.fontSize(10)
            font.letterSpacing: 0.8
        }

        Text {
            anchors.centerIn: parent
            visible: adapterAvailable && system.bluetoothEnabled && devices.length === 0
            width: parent.width
            text: system.bluetoothDiscovering ? "SCANNING // NO DEVICES YET" : "NO DEVICES // PRESS D TO SCAN"
            horizontalAlignment: Text.AlignHCenter
            color: theme.textMuted
            font.family: runtime.fontMono
            font.pixelSize: theme.fontSize(10)
            font.letterSpacing: 0.8
        }
    }

    Column {
        id: footer

        anchors {
            right: parent.right
            bottom: parent.bottom
            left: parent.left
        }
        spacing: theme.spacing2

        Text {
            width: parent.width
            visible: statusText.length > 0
            text: statusText
            horizontalAlignment: Text.AlignRight
            color: statusError ? theme.critical : (forgetAddress.length > 0 ? theme.warning : theme.accent)
            font.family: runtime.fontMono
            font.pixelSize: theme.fontSize(8)
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
            elide: Text.ElideRight
        }

        Row {
            anchors.right: parent.right
            spacing: theme.spacing3

            Text {
                text: "↑/↓  SELECT"
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(8)
            }

            Text {
                text: "ENTER  LINK"
                color: theme.accent
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(8)
            }

            Text {
                text: "B  RADIO"
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(8)
            }

            Text {
                text: "D  SCAN"
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(8)
            }
        }

        Row {
            anchors.right: parent.right
            spacing: theme.spacing3

            Text {
                text: "P  PAIR"
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(8)
            }

            Text {
                text: "T  TRUST"
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(8)
            }

            Text {
                text: forgetAddress.length > 0 ? "F  CONFIRM" : "F  FORGET"
                color: forgetAddress.length > 0 ? theme.warning : theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(8)
            }

            Text {
                text: "ESC  BACK"
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(8)
            }
        }
    }
}
