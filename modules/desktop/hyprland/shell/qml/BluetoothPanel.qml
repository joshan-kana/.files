pragma ComponentBehavior: Bound
import QtQuick
import "DesktopIcons.js" as DesktopIcons
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
    property bool deviceDetail: false
    property bool renaming: false
    property string detailAddress: ""
    readonly property var detailDevice: devices.find(device => device.address === detailAddress) || null

    function toggleDeviceDetail(): void {
        if (deviceDetail) {
            renaming = false;
            deviceDetail = false;
            detailAddress = "";
        } else {
            const device = selectedDevice();
            if (!device)
                return;
            detailAddress = device.address;
            deviceDetail = true;
        }
        clearTransientState();
        keyboardRequested();
    }

    function renameDevice(): void {
        if (!detailDevice || !detailDevice.paired)
            return;
        renaming = true;
        nameInput.text = detailDevice.name;
        nameInput.forceActiveFocus();
        nameInput.selectAll();
    }

    function finishRename(save: bool): void {
        if (save && detailDevice && detailDevice.paired && nameInput.text.trim().length > 0)
            detailDevice.name = nameInput.text.trim();
        renaming = false;
        keyboardRequested();
    }

    function toggleWake(): void {
        if (detailDevice && detailDevice.paired)
            detailDevice.wakeAllowed = !detailDevice.wakeAllowed;
    }

    property int selectedIndex: 0
    property bool startedDiscovery: false
    property string forgetAddress: ""
    property string statusText: ""
    property bool statusError: false

    readonly property string foregroundRole: "connectivity"
    readonly property bool foregroundBusy: devices.some(device => device.pairing)
    readonly property var adapter: system.bluetoothAdapter
    readonly property var devices: system.bluetoothAdapterDevices || []
    readonly property bool adapterAvailable: system.bluetoothAvailable

    readonly property real bodyHeight: deviceDetail ? 310 : adapterAvailable && adapter.enabled ? Math.min(440, Math.max(196, devices.length * 100)) : emptyState.implicitHeight + panel.theme.spacing3 + panel.theme.spacing4
    implicitHeight: header.height + statusBanner.implicitHeight + panel.theme.spacing4 * 2 + bodyHeight + panel.theme.spacing3 + footer.implicitHeight
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
        deviceDetail = false;
        renaming = false;
        detailAddress = "";
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
            statusText = "PAIR FIRST // PRESS " + runtime.shellHint("BluetoothPanel.pair");
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
        statusText = "CONFIRM FORGET // PRESS " + runtime.shellHint("BluetoothPanel.forget") + " AGAIN";
        statusError = false;
        forgetTimer.restart();
    }

    onDevicesChanged: {
        selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, devices.length - 1)));
    }

    DetailHero {
        id: header
        width: parent.width
        height: implicitHeight
        runtime: panel.runtime
        theme: panel.theme
        motion: panel.motion
        glyph: DesktopIcons.capabilityGlyph("bluetooth", {
            active: panel.system.bluetoothEnabled
        })
        glyphFont: "Symbols Nerd Font"
        glyphColor: panel.system.bluetoothEnabled ? panel.theme.positive : panel.theme.textMuted
        eyebrow: "Connectivity / Bluetooth"
        title: panel.deviceDetail ? "Device settings" : "Bluetooth"
        detail: !panel.adapterAvailable ? "No adapter available" : panel.system.bluetoothEnabled ? panel.system.bluetoothConnectedCount + " connected · " + (panel.system.bluetoothDiscovering ? "Scanning…" : "Scan idle") : "Radio disabled"
    }

    PanelStatus {
        id: statusBanner
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            topMargin: panel.theme.spacing2
        }
        runtime: panel.runtime
        theme: panel.theme
        motion: panel.motion
        message: panel.statusText
        idleMessage: !panel.adapterAvailable ? "Bluetooth adapter unavailable" : !panel.system.bluetoothEnabled ? "Bluetooth radio disabled" : panel.devices.length === 0 ? "Scanning for Bluetooth devices" : "Select a device or scan"
        phase: panel.statusError ? "error" : panel.forgetAddress.length > 0 ? "warning" : panel.statusText.startsWith("CONNECTING") || panel.statusText.startsWith("DISCONNECTING") || panel.statusText.startsWith("PAIRING") ? "busy" : "idle"
    }

    Item {
        anchors {
            top: statusBanner.bottom
            right: parent.right
            bottom: footer.top
            left: parent.left
            topMargin: panel.theme.spacing4
            bottomMargin: panel.theme.spacing3
        }

        Column {
            anchors.fill: parent
            spacing: panel.theme.spacing2
            visible: panel.deviceDetail && panel.detailDevice !== null
            Text {
                width: parent.width
                text: panel.detailDevice ? panel.displayName(panel.detailDevice) + " · " + panel.detailDevice.address : ""
                font.family: panel.runtime.fontSans
                font.pixelSize: panel.theme.fontSize(15)
                color: panel.theme.textStrong
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: panel.detailDevice ? "Adapter: " + (panel.adapter?.name || "Unknown") + " · " + (panel.detailDevice.deviceName || "Unnamed") + " · " + (panel.detailDevice.bonded ? "Bonded" : "Not bonded") + (panel.detailDevice.blocked ? " · Blocked" : "") : ""
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(10)
                color: panel.theme.textMuted
                wrapMode: Text.Wrap
            }
            ShellAction {
                width: parent.width
                height: 48
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                title: "Rename device"
                shortcut: panel.runtime.shellHint("BluetoothPanel.rename")
                horizontalCompact: true
                enabled: !!panel.detailDevice?.paired
                visible: !panel.renaming
                onActivated: panel.renameDevice()
            }
            ShellSurface {
                width: parent.width
                height: 50
                theme: panel.theme
                motion: panel.motion
                surfaceLayer: ShellSurface.Control
                cornerRadius: panel.theme.radiusMedium
                visible: panel.renaming
                TextInput {
                    id: nameInput
                    anchors.fill: parent
                    anchors.margins: panel.theme.spacing3
                    color: panel.theme.textStrong
                    font.family: panel.runtime.fontSans
                    font.pixelSize: panel.theme.fontSize(13)
                    maximumLength: 248
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    Keys.onPressed: event => {
                        if (event.key === panel.runtime.shellKeyCode("controls", "Escape")) {
                            panel.finishRename(false);
                            event.accepted = true;
                        } else if (event.key === panel.runtime.shellKeyCode("controls", "Return") || event.key === panel.runtime.shellKeyCode("controls", "Enter")) {
                            panel.finishRename(true);
                            event.accepted = true;
                        }
                    }
                }
            }
            ShellAction {
                width: parent.width
                height: 48
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                title: "Allow device to wake computer"
                shortcut: panel.runtime.shellHint("BluetoothPanel.wake")
                horizontalCompact: true
                active: !!panel.detailDevice?.wakeAllowed
                enabled: !!panel.detailDevice?.paired
                visible: !panel.renaming
                onActivated: panel.toggleWake()
            }
            Text {
                width: parent.width
                text: panel.detailDevice?.batteryAvailable ? "Battery: " + Math.round(panel.detailDevice.battery * 100) + "%" : "Battery level unavailable"
                font.family: panel.runtime.fontSans
                font.pixelSize: panel.theme.fontSize(11)
                color: panel.theme.textMuted
            }
        }

        ListView {
            id: deviceList

            anchors.fill: parent
            visible: !panel.deviceDetail && panel.adapterAvailable && panel.adapter.enabled
            model: panel.devices
            spacing: panel.theme.spacing2
            clip: true
            currentIndex: panel.selectedIndex
            boundsBehavior: Flickable.StopAtBounds

            delegate: ShellListRow {
                id: deviceRow

                required property var modelData
                required property int index

                width: ListView.view.width
                height: Math.max(92, panel.theme.fontSize(84))
                theme: panel.theme
                motion: panel.motion
                selected: index === panel.selectedIndex
                fillColor: deviceRow.modelData.connected ? panel.theme.blend(panel.theme.groupBase, panel.theme.positive, panel.theme.dark ? 0.11 : 0.07) : panel.theme.layer3

                pressedFeedback: devicePress.visualPressed
                selectionColor: panel.theme.roleColor("connectivity")

                StateLayer {
                    id: devicePress
                    theme: panel.theme
                    motion: panel.motion
                    selected: deviceRow.index === panel.selectedIndex
                    cornerRadius: deviceRow.cornerRadius

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

                        MarqueeText {
                            width: parent.width
                            text: panel.displayName(deviceRow.modelData)
                            color: panel.theme.textStrong
                            font.family: panel.runtime.fontSans
                            font.pixelSize: panel.theme.fontSize(13)
                            font.weight: deviceRow.modelData.connected ? Font.DemiBold : Font.Normal
                        }

                        Text {
                            width: parent.width
                            text: deviceRow.modelData.address
                            color: panel.theme.textMuted
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontUtility
                            elide: Text.ElideRight
                        }

                        Row {
                            spacing: panel.theme.spacing2

                            Text {
                                text: BluetoothDeviceState.toString(deviceRow.modelData.state).toUpperCase()
                                color: deviceRow.modelData.connected ? panel.theme.positive : panel.theme.textMuted
                                font.family: panel.runtime.fontSans
                                font.pixelSize: panel.theme.fontUtility
                                font.weight: Font.DemiBold
                            }

                            Text {
                                text: deviceRow.modelData.pairing ? "Pairing" : (deviceRow.modelData.paired ? "Paired" : "Unpaired")
                                color: panel.theme.readableRoleColor(deviceRow.modelData.paired || deviceRow.modelData.pairing ? "connectivity" : "warning")
                                font.family: panel.runtime.fontSans
                                font.pixelSize: panel.theme.fontUtility
                                font.weight: Font.DemiBold
                            }

                            Text {
                                visible: deviceRow.modelData.trusted
                                text: "Trusted"
                                color: panel.theme.roleColor("connectivity")
                                font.family: panel.runtime.fontSans
                                font.pixelSize: panel.theme.fontUtility
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Column {
                        width: 114
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: panel.theme.spacing1

                        KeyHint {
                            anchors.right: parent.right
                            runtime: panel.runtime
                            theme: panel.theme
                            compact: true
                            shortcut: !deviceRow.selected ? "" : deviceRow.modelData.pairing || !deviceRow.modelData.paired ? panel.runtime.shellHint("BluetoothPanel.pair") : panel.runtime.shellHint("BluetoothPanel.activate")
                            label: deviceRow.modelData.pairing ? "Cancel" : !deviceRow.modelData.paired ? "Pair" : deviceRow.modelData.connected ? "Drop" : "Link"
                        }

                        Text {
                            width: parent.width
                            visible: deviceRow.modelData.batteryAvailable
                            horizontalAlignment: Text.AlignRight
                            text: "BAT " + Math.round(deviceRow.modelData.battery * 100) + "%"
                            color: deviceRow.modelData.battery <= 0.20 ? panel.theme.warning : panel.theme.textMuted
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontUtility
                        }
                    }
                }
            }

            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        }

        ConnectivityUnavailableCard {
            id: emptyState
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            visible: !panel.adapterAvailable
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            statusText: "BLUETOOTH UNAVAILABLE"
            heading: "No Bluetooth adapter"
            description: "Connect or enable an adapter to discover and pair devices."
        }

        Text {
            anchors.centerIn: parent
            visible: panel.adapterAvailable && !panel.system.bluetoothEnabled
            width: parent.width
            text: "Bluetooth radio is off"
            horizontalAlignment: Text.AlignHCenter
            color: panel.theme.readableRoleColor("warning")
            font.family: panel.runtime.fontSans
            font.pixelSize: panel.theme.fontSize(10)
            font.letterSpacing: 0.8
        }

        Text {
            anchors.centerIn: parent
            visible: panel.adapterAvailable && panel.system.bluetoothEnabled && panel.devices.length === 0
            width: parent.width
            text: panel.system.bluetoothDiscovering ? "Scanning for devices…" : "No devices found"
            horizontalAlignment: Text.AlignHCenter
            color: panel.theme.textMuted
            font.family: panel.runtime.fontSans
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

        ShellAction {
            width: parent.width
            height: 40
            runtime: panel.runtime
            theme: panel.theme
            motion: panel.motion
            compact: true
            horizontalCompact: true
            visible: panel.deviceDetail || (panel.adapterAvailable && panel.devices.length > 0)
            title: panel.deviceDetail ? "Back to devices" : "Device settings"
            shortcut: panel.runtime.shellHint("BluetoothPanel.detail")
            onActivated: panel.toggleDeviceDetail()
        }

        KeyHintStrip {
            visible: !panel.deviceDetail
            width: parent.width
            runtime: panel.runtime
            theme: panel.theme
            hints: [
                {
                    shortcut: panel.runtime.shellHint("BluetoothPanel.select"),
                    label: "Select",
                    visible: panel.adapterAvailable && panel.system.bluetoothEnabled && panel.devices.length > 0
                },
                {
                    shortcut: panel.runtime.shellHint("BluetoothPanel.activate"),
                    label: panel.selectedDevice()?.connected ? "Drop" : "Link",
                    visible: panel.adapterAvailable && panel.system.bluetoothEnabled && panel.selectedDevice()?.paired === true
                },
                {
                    shortcut: panel.runtime.shellHint("BluetoothPanel.radio"),
                    label: "Radio",
                    visible: panel.adapterAvailable
                },
                {
                    shortcut: panel.runtime.shellHint("BluetoothPanel.scan"),
                    label: "Scan",
                    visible: panel.adapterAvailable && panel.system.bluetoothEnabled
                },
                {
                    shortcut: panel.runtime.shellHint("BluetoothPanel.pair"),
                    label: panel.selectedDevice()?.pairing ? "Cancel pairing" : "Pair",
                    visible: panel.adapterAvailable && panel.system.bluetoothEnabled && panel.devices.length > 0
                },
                {
                    shortcut: panel.runtime.shellHint("BluetoothPanel.trust"),
                    label: panel.selectedDevice()?.trusted ? "Untrust" : "Trust",
                    visible: panel.adapterAvailable && panel.system.bluetoothEnabled && panel.selectedDevice()?.paired === true
                },
                {
                    shortcut: panel.runtime.shellHint("BluetoothPanel.forget"),
                    label: panel.forgetAddress.length > 0 ? "Confirm" : "Forget",
                    visible: panel.adapterAvailable && panel.system.bluetoothEnabled && panel.selectedDevice()?.paired === true
                }
            ]
        }
    }
}
