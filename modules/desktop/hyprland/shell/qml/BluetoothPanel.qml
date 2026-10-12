pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Item {
    id: panel

    required property SystemState system
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

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

    implicitHeight: header.height + panel.theme.spacing4 * 3 + (adapterAvailable && adapter.enabled ? Math.min(440, Math.max(196, devices.length * 100)) : 190) + footer.implicitHeight
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

    function moveHalfPage(direction: int): void {
        const rowHeight = deviceList.currentItem ? deviceList.currentItem.height + deviceList.spacing : 64;
        const rows = Math.max(1, Math.floor(deviceList.height / Math.max(1, rowHeight) / 2));
        moveSelection(direction * rows);
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

    DetailHero {
        id: header
        width: parent.width
        height: 128
        runtime: panel.runtime
        theme: panel.theme
        motion: panel.motion
        glyph: panel.system.bluetoothEnabled ? "󰂯" : "󰂲"
        glyphColor: panel.system.bluetoothEnabled ? panel.theme.positive : panel.theme.textMuted
        eyebrow: "Connectivity / Bluetooth"
        title: "Bluetooth"
        detail: !panel.adapterAvailable ? "No adapter available" : panel.system.bluetoothEnabled ? panel.system.bluetoothConnectedCount + " connected · " + (panel.system.bluetoothDiscovering ? "Scanning…" : "Scan idle") : "Radio disabled"
    }

    Item {
        anchors {
            top: header.bottom
            right: parent.right
            bottom: footer.top
            left: parent.left
            topMargin: panel.theme.spacing4
            bottomMargin: panel.theme.spacing3
        }

        ListView {
            id: deviceList

            anchors.fill: parent
            visible: panel.adapterAvailable && panel.adapter.enabled
            model: panel.devices
            spacing: panel.theme.spacing2
            clip: true
            currentIndex: panel.selectedIndex
            boundsBehavior: Flickable.StopAtBounds

            delegate: ShellSurface {
                id: deviceRow

                required property var modelData
                required property int index

                width: ListView.view.width
                height: 92
                theme: panel.theme
                motion: panel.motion
                surfaceLayer: ShellSurface.Control
                selected: index === panel.selectedIndex
                cornerRadius: theme.radiusLarge
                fillColor: deviceRow.modelData.connected ? panel.theme.blend(panel.theme.groupBase, panel.theme.positive, panel.theme.dark ? 0.11 : 0.07) : panel.theme.layer3

                StateLayer {
                    theme: panel.theme
                    motion: panel.motion
                    selected: deviceRow.index === panel.selectedIndex
                    cornerRadius: panel.theme.radiusLarge

                    onActivated: {
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
                        margins: panel.theme.spacing3
                    }
                    spacing: panel.theme.spacing3

                    Column {
                        width: parent.width - 126
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: panel.theme.spacing1

                        Text {
                            width: parent.width
                            text: panel.displayName(deviceRow.modelData)
                            color: panel.theme.textStrong
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(13)
                            font.weight: deviceRow.modelData.connected ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: deviceRow.modelData.address
                            color: panel.theme.textMuted
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(8)
                            elide: Text.ElideRight
                        }

                        Row {
                            spacing: panel.theme.spacing2

                            Text {
                                text: BluetoothDeviceState.toString(deviceRow.modelData.state).toUpperCase()
                                color: deviceRow.modelData.connected ? panel.theme.positive : panel.theme.textMuted
                                font.family: panel.runtime.fontMono
                                font.pixelSize: panel.theme.fontSize(8)
                                font.weight: Font.DemiBold
                            }

                            Text {
                                text: deviceRow.modelData.pairing ? "PAIRING" : (deviceRow.modelData.paired ? "PAIRED" : "UNPAIRED")
                                color: deviceRow.modelData.paired || deviceRow.modelData.pairing ? panel.theme.accent : panel.theme.warning
                                font.family: panel.runtime.fontMono
                                font.pixelSize: panel.theme.fontSize(8)
                                font.weight: Font.DemiBold
                            }

                            Text {
                                visible: deviceRow.modelData.trusted
                                text: "TRUSTED"
                                color: panel.theme.accent
                                font.family: panel.runtime.fontMono
                                font.pixelSize: panel.theme.fontSize(8)
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Column {
                        width: 114
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: panel.theme.spacing1

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignRight
                            text: deviceRow.modelData.pairing ? "P  CANCEL" : (!deviceRow.modelData.paired ? "P  PAIR" : (deviceRow.modelData.connected ? "ENTER  DROP" : "ENTER  LINK"))
                            color: deviceRow.modelData.pairing || !deviceRow.modelData.paired ? panel.theme.warning : panel.theme.accent
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(8)
                            font.weight: Font.DemiBold
                        }

                        Text {
                            width: parent.width
                            visible: deviceRow.modelData.batteryAvailable
                            horizontalAlignment: Text.AlignRight
                            text: "BAT " + Math.round(deviceRow.modelData.battery * 100) + "%"
                            color: deviceRow.modelData.battery <= 0.20 ? panel.theme.warning : panel.theme.textMuted
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(8)
                        }
                    }
                }
            }

            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        }

        ShellSurface {
            anchors.centerIn: parent
            width: parent.width
            height: 158
            visible: !panel.adapterAvailable
            theme: panel.theme
            motion: panel.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: panel.theme.radiusLarge

            Column {
                width: parent.width - panel.theme.spacing5 * 2
                anchors.centerIn: parent
                spacing: panel.theme.spacing3

                Text {
                    text: "BLUETOOTH UNAVAILABLE"
                    color: panel.theme.warning
                    font.family: panel.runtime.fontMono
                    font.pixelSize: panel.theme.fontSize(11)
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "No Bluetooth adapter"
                    color: panel.theme.textStrong
                    font.family: panel.runtime.fontMono
                    font.pixelSize: panel.theme.fontSize(20)
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "Connect or enable an adapter to discover and pair devices."
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: panel.theme.textMuted
                    font.family: panel.runtime.fontMono
                    font.pixelSize: panel.theme.fontSize(10)
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: panel.adapterAvailable && !panel.system.bluetoothEnabled
            width: parent.width
            text: "Bluetooth is off · press B to enable"
            horizontalAlignment: Text.AlignHCenter
            color: panel.theme.warning
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(10)
            font.letterSpacing: 0.8
        }

        Text {
            anchors.centerIn: parent
            visible: panel.adapterAvailable && panel.system.bluetoothEnabled && panel.devices.length === 0
            width: parent.width
            text: panel.system.bluetoothDiscovering ? "SCANNING // NO DEVICES YET" : "NO DEVICES // PRESS D TO SCAN"
            horizontalAlignment: Text.AlignHCenter
            color: panel.theme.textMuted
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(10)
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
        spacing: panel.theme.spacing2

        Text {
            width: parent.width
            visible: panel.statusText.length > 0
            text: panel.statusText
            horizontalAlignment: Text.AlignRight
            color: panel.statusError ? panel.theme.critical : (panel.forgetAddress.length > 0 ? panel.theme.warning : panel.theme.accent)
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(8)
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
            elide: Text.ElideRight
        }

        Row {
            anchors.right: parent.right
            spacing: panel.theme.spacing3

            Text {
                text: "↑/↓  SELECT"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontKeyHint
            }

            Text {
                text: "ENTER  LINK"
                color: panel.theme.accent
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontKeyHint
            }

            Text {
                text: "B  RADIO"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontKeyHint
            }

            Text {
                text: "D  SCAN"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontKeyHint
            }
        }

        Row {
            anchors.right: parent.right
            spacing: panel.theme.spacing3

            Text {
                text: "P  PAIR"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontKeyHint
            }

            Text {
                text: "T  TRUST"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontKeyHint
            }

            Text {
                text: panel.forgetAddress.length > 0 ? "F  CONFIRM" : "F  FORGET"
                color: panel.forgetAddress.length > 0 ? panel.theme.warning : panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontKeyHint
            }

            Text {
                text: "ESC  BACK"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontKeyHint
            }
        }
    }
}
