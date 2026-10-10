pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Networking

Item {
    id: panel

    required property SystemState system
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    signal keyboardRequested

    property bool open: false
    property int selectedIndex: 0
    property var pendingNetwork: null
    property string password: ""
    property string statusText: ""
    property bool statusError: false

    readonly property var networks: system.wifiNetworks || []
    readonly property bool passwordPrompt: pendingNetwork !== null

    visible: open

    function selectedNetwork(): var {
        if (networks.length === 0)
            return null;

        return networks[Math.max(0, Math.min(selectedIndex, networks.length - 1))];
    }

    function selectedNetworkIndex(): int {
        for (let index = 0; index < networks.length; index++) {
            if (networks[index].connected)
                return index;
        }

        return 0;
    }

    function openView(): void {
        open = true;
        pendingNetwork = null;
        password = "";
        statusText = "";
        statusError = false;
        selectedIndex = selectedNetworkIndex();

        if (system.wifiDevice)
            system.wifiDevice.scannerEnabled = true;

        keyboardRequested();
    }

    function closeView(): void {
        if (system.wifiDevice)
            system.wifiDevice.scannerEnabled = false;

        pendingNetwork = null;
        password = "";
        statusText = "";
        statusError = false;
        open = false;
        keyboardRequested();
    }

    function moveHalfPage(direction: int): void {
        const rowHeight = networkList.currentItem ? networkList.currentItem.height + networkList.spacing : 64;
        const rows = Math.max(1, Math.floor(networkList.height / Math.max(1, rowHeight) / 2));
        moveSelection(direction * rows);
    }

    function moveSelection(delta: int): void {
        if (networks.length === 0)
            return;

        selectedIndex = Math.max(0, Math.min(networks.length - 1, selectedIndex + delta));
    }

    function supportsPsk(network): bool {
        return network && (network.security === WifiSecurityType.WpaPsk || network.security === WifiSecurityType.Wpa2Psk || network.security === WifiSecurityType.Sae);
    }

    function needsAdvancedConfiguration(network): bool {
        if (!network || network.known)
            return false;

        return network.security === WifiSecurityType.WpaEap || network.security === WifiSecurityType.Wpa2Eap || network.security === WifiSecurityType.Wpa3SuiteB192 || network.security === WifiSecurityType.StaticWep || network.security === WifiSecurityType.DynamicWep || network.security === WifiSecurityType.Leap || network.security === WifiSecurityType.Unknown;
    }

    function promptForPassword(network, message): void {
        pendingNetwork = network;
        password = "";
        statusText = message || ("PASSWORD // " + network.name);
        statusError = false;
        Qt.callLater(() => passwordInput.forceActiveFocus());
    }

    function cancelPassword(): void {
        pendingNetwork = null;
        password = "";
        statusText = "";
        statusError = false;
        keyboardRequested();
    }

    function submitPassword(): void {
        if (!pendingNetwork || password.length === 0)
            return;

        const network = pendingNetwork;
        const secret = password;

        password = "";
        pendingNetwork = null;
        statusText = "CONNECTING // " + network.name;
        statusError = false;
        network.connectWithPsk(secret);
        keyboardRequested();
    }

    function activateSelected(): void {
        const network = selectedNetwork();
        if (!network || network.stateChanging)
            return;

        statusText = "";
        statusError = false;

        if (network.connected) {
            statusText = "DISCONNECTING // " + network.name;
            network.disconnect();
            return;
        }

        if (network.known || network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe) {
            statusText = "CONNECTING // " + network.name;
            network.connect();
            return;
        }

        if (supportsPsk(network)) {
            promptForPassword(network, "PASSWORD // " + network.name);
            return;
        }

        if (needsAdvancedConfiguration(network)) {
            statusText = "ADVANCED PROFILE REQUIRED // " + WifiSecurityType.toString(network.security);
            statusError = true;
            return;
        }

        network.connect();
    }

    function toggleWifi(): void {
        if (!system.wifiAvailable)
            return;

        system.setWifiEnabled(!system.wifiEnabled);
        statusText = system.wifiEnabled ? "DISABLING WI-FI" : "ENABLING WI-FI";
        statusError = false;
    }

    Connections {
        target: panel.system

        function onWifiNetworksChanged(): void {
            panel.selectedIndex = Math.max(0, Math.min(panel.selectedIndex, Math.max(0, panel.networks.length - 1)));
        }
    }

    Column {
        id: header

        width: parent.width
        spacing: panel.theme.spacing1

        Text {
            text: "Network · " + panel.system.connectivityText.toLowerCase()
            color: panel.system.networkConnected ? panel.theme.positive : panel.theme.warning
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(11)
            font.weight: Font.Medium
        }

        Text {
            text: panel.system.wifiAvailable ? "Wi-Fi" : "Network"
            color: panel.theme.textStrong
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSubpanelTitle
            font.weight: Font.DemiBold
        }

        Row {
            width: parent.width
            spacing: panel.theme.spacing3

            Text {
                text: panel.system.networkConnected ? panel.system.networkName : "Offline"
                color: panel.theme.text
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(9)
            }

            Text {
                visible: panel.system.wifiAvailable
                text: panel.system.wifiEnabled ? "RADIO ON" : "RADIO OFF"
                color: panel.system.wifiEnabled ? panel.theme.accent : panel.theme.critical
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(9)
            }

            Text {
                visible: panel.system.wifiAvailable && !panel.system.wifiHardwareEnabled
                text: "Wi-Fi hardware unavailable"
                color: panel.theme.critical
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(9)
            }
        }
    }

    Item {
        id: body

        anchors {
            top: header.bottom
            right: parent.right
            bottom: footer.top
            left: parent.left
            topMargin: panel.theme.spacing4
            bottomMargin: panel.theme.spacing3
        }

        ListView {
            id: networkList

            anchors.fill: parent
            visible: panel.system.wifiAvailable && panel.system.wifiEnabled && !panel.passwordPrompt
            model: panel.networks
            spacing: panel.theme.spacing2
            clip: true
            currentIndex: panel.selectedIndex
            boundsBehavior: Flickable.StopAtBounds

            delegate: ShellSurface {
                id: networkRow

                required property var modelData
                required property int index

                width: ListView.view.width
                height: 66
                theme: panel.theme
                motion: panel.motion
                surfaceLayer: ShellSurface.Control
                selected: index === panel.selectedIndex
                cornerRadius: theme.radiusMedium

                StateLayer {
                    theme: panel.theme
                    motion: panel.motion
                    selected: networkRow.index === panel.selectedIndex
                    cornerRadius: panel.theme.radiusMedium
                    onActivated: {
                        panel.selectedIndex = networkRow.index;
                        panel.activateSelected();
                    }
                }

                Row {
                    anchors {
                        fill: parent
                        margins: panel.theme.spacing3
                    }
                    spacing: panel.theme.spacing3

                    Column {
                        width: parent.width - 112
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Row {
                            width: parent.width
                            spacing: panel.theme.spacing2

                            Text {
                                width: parent.width - statusBadge.width - parent.spacing
                                text: networkRow.modelData.name
                                color: panel.theme.textStrong
                                font.family: panel.runtime.fontMono
                                font.pixelSize: panel.theme.fontSize(13)
                                font.weight: networkRow.modelData.connected ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }

                            Text {
                                id: statusBadge
                                text: networkRow.modelData.connected ? "CONNECTED" : (networkRow.modelData.known ? "KNOWN" : "")
                                color: networkRow.modelData.connected ? panel.theme.positive : panel.theme.textMuted
                                font.family: panel.runtime.fontMono
                                font.pixelSize: panel.theme.fontSize(8)
                                font.weight: Font.DemiBold
                            }
                        }

                        Text {
                            width: parent.width
                            text: WifiSecurityType.toString(networkRow.modelData.security).toUpperCase() + " // SIG " + Math.round(networkRow.modelData.signalStrength * 100)
                            color: panel.theme.textMuted
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(8)
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        width: 100
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: networkRow.modelData.stateChanging ? ConnectionState.toString(networkRow.modelData.state).toUpperCase() : (networkRow.modelData.connected ? "ENTER // DROP" : "ENTER // JOIN")
                        color: networkRow.modelData.stateChanging ? panel.theme.warning : panel.theme.accent
                        font.family: panel.runtime.fontMono
                        font.pixelSize: panel.theme.fontSize(8)
                        font.weight: Font.DemiBold
                    }
                }

                Connections {
                    target: networkRow.modelData

                    function onConnectionFailed(reason): void {
                        if (reason === ConnectionFailReason.NoSecrets && panel.supportsPsk(networkRow.modelData)) {
                            panel.promptForPassword(networkRow.modelData, "AUTH REQUIRED // " + networkRow.modelData.name);
                            return;
                        }

                        panel.statusText = ConnectionFailReason.toString(reason).toUpperCase();
                        panel.statusError = true;
                        panel.keyboardRequested();
                    }

                    function onConnectedChanged(): void {
                        if (networkRow.modelData.connected) {
                            panel.statusText = "CONNECTED // " + networkRow.modelData.name;
                            panel.statusError = false;
                        }
                    }
                }
            }

            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        }

        Column {
            anchors.centerIn: parent
            width: parent.width
            visible: panel.passwordPrompt
            spacing: panel.theme.spacing3

            Text {
                width: parent.width
                text: panel.pendingNetwork ? panel.pendingNetwork.name : ""
                horizontalAlignment: Text.AlignHCenter
                color: panel.theme.textStrong
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(18)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: panel.pendingNetwork ? WifiSecurityType.toString(panel.pendingNetwork.security).toUpperCase() : ""
                horizontalAlignment: Text.AlignHCenter
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(9)
                font.letterSpacing: 1
            }

            ShellSurface {
                width: parent.width
                height: 50
                theme: panel.theme
                motion: panel.motion
                surfaceLayer: ShellSurface.Group
                cornerRadius: theme.radiusMedium
                outlined: passwordInput.activeFocus
                borderColor: passwordInput.activeFocus ? theme.accent : theme.subtleBorder

                TextInput {
                    id: passwordInput

                    anchors {
                        fill: parent
                        leftMargin: panel.theme.spacing4
                        rightMargin: panel.theme.spacing4
                    }

                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                    color: panel.theme.textStrong
                    selectionColor: panel.theme.accent
                    selectedTextColor: panel.theme.background
                    font.family: panel.runtime.fontMono
                    font.pixelSize: panel.theme.fontSize(15)
                    clip: true

                    onTextEdited: panel.password = text

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            panel.cancelPassword();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            panel.submitPassword();
                            event.accepted = true;
                        }
                    }

                    Connections {
                        target: panel

                        function onPasswordChanged(): void {
                            if (passwordInput.text !== panel.password)
                                passwordInput.text = panel.password;
                        }
                    }
                }
            }

            Text {
                width: parent.width
                text: "ENTER  CONNECT   //   ESC  CANCEL"
                horizontalAlignment: Text.AlignHCenter
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(8)
                font.letterSpacing: 0.8
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !panel.system.wifiAvailable && !panel.passwordPrompt
            width: parent.width
            text: panel.system.networkConnected ? "WIRED LINK // " + panel.system.networkName : "NO WI-FI DEVICE // NETWORK OFFLINE"
            horizontalAlignment: Text.AlignHCenter
            color: panel.system.networkConnected ? panel.theme.text : panel.theme.textMuted
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(10)
            font.letterSpacing: 0.8
        }

        Text {
            anchors.centerIn: parent
            visible: panel.system.wifiAvailable && !panel.system.wifiEnabled && !panel.passwordPrompt
            width: parent.width
            text: panel.system.wifiHardwareEnabled ? "WI-FI RADIO DISABLED // PRESS W" : "WI-FI DISABLED BY HARDWARE"
            horizontalAlignment: Text.AlignHCenter
            color: panel.system.wifiHardwareEnabled ? panel.theme.warning : panel.theme.critical
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
            horizontalAlignment: Text.AlignHCenter
            color: panel.statusError ? panel.theme.critical : panel.theme.accent
            font.family: panel.runtime.fontMono
            font.pixelSize: panel.theme.fontSize(8)
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
            elide: Text.ElideRight
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: panel.theme.spacing4

            Text {
                visible: panel.system.wifiAvailable
                text: "↑↓  SELECT   ENTER  JOIN/DROP"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontKeyHint
                font.letterSpacing: 0.8
            }

            Text {
                visible: panel.system.wifiAvailable
                text: "W  WI-FI"
                color: panel.theme.accent
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontKeyHint
                font.letterSpacing: 0.8
            }

            Text {
                text: "A  ADVANCED"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontKeyHint
                font.letterSpacing: 0.8
            }

            Text {
                text: "ESC  BACK"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontKeyHint
                font.letterSpacing: 0.8
            }
        }
    }
}
