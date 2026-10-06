import QtQuick
import Quickshell
import Quickshell.Networking

Item {
    id: panel

    required property QtObject system
    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

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
        target: system

        function onWifiNetworksChanged(): void {
            panel.selectedIndex = Math.max(0, Math.min(panel.selectedIndex, Math.max(0, panel.networks.length - 1)));
        }
    }

    Column {
        id: header

        width: parent.width
        spacing: theme.spacing1

        Text {
            text: "Network · " + system.connectivityText.toLowerCase()
            color: system.networkConnected ? theme.positive : theme.warning
            font.family: runtime.fontSans
            font.pixelSize: theme.fontSize(11)
            font.weight: Font.Medium
        }

        Text {
            text: system.wifiAvailable ? "Wi-Fi" : "Network"
            color: theme.textStrong
            font.family: runtime.fontSans
            font.pixelSize: theme.fontSubpanelTitle
            font.weight: Font.DemiBold
        }

        Row {
            width: parent.width
            spacing: theme.spacing3

            Text {
                text: system.networkConnected ? system.networkName : "Offline"
                color: theme.text
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(9)
            }

            Text {
                visible: system.wifiAvailable
                text: system.wifiEnabled ? "RADIO ON" : "RADIO OFF"
                color: system.wifiEnabled ? theme.accent : theme.critical
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(9)
            }

            Text {
                visible: system.wifiAvailable && !system.wifiHardwareEnabled
                text: "Wi-Fi hardware unavailable"
                color: theme.critical
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(9)
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
            topMargin: theme.spacing4
            bottomMargin: theme.spacing3
        }

        ListView {
            id: networkList

            anchors.fill: parent
            visible: system.wifiAvailable && system.wifiEnabled && !panel.passwordPrompt
            model: panel.networks
            spacing: theme.spacing2
            clip: true
            currentIndex: panel.selectedIndex
            boundsBehavior: Flickable.StopAtBounds

            delegate: SquircleSurface {
                id: networkRow

                required property var modelData
                required property int index

                width: ListView.view.width
                height: 66
                exponent: theme.squircleExponent
                cornerRadius: theme.radiusMedium
                fillColor: index === panel.selectedIndex ? theme.focusFill : theme.background
                borderColor: modelData.connected ? theme.positive : (index === panel.selectedIndex ? theme.accent : theme.outline)
                borderWidth: index === panel.selectedIndex || modelData.connected ? theme.borderFocus : theme.borderThin

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        panel.selectedIndex = networkRow.index;
                        panel.activateSelected();
                    }
                }

                Row {
                    anchors {
                        fill: parent
                        margins: theme.spacing3
                    }
                    spacing: theme.spacing3

                    Column {
                        width: parent.width - 112
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Row {
                            width: parent.width
                            spacing: theme.spacing2

                            Text {
                                width: parent.width - statusBadge.width - parent.spacing
                                text: modelData.name
                                color: theme.textStrong
                                font.family: runtime.fontSans
                                font.pixelSize: theme.fontSize(13)
                                font.weight: modelData.connected ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }

                            Text {
                                id: statusBadge
                                text: modelData.connected ? "CONNECTED" : (modelData.known ? "KNOWN" : "")
                                color: modelData.connected ? theme.positive : theme.textMuted
                                font.family: runtime.fontMono
                                font.pixelSize: theme.fontSize(8)
                                font.weight: Font.DemiBold
                            }
                        }

                        Text {
                            width: parent.width
                            text: WifiSecurityType.toString(modelData.security).toUpperCase() + " // SIG " + Math.round(modelData.signalStrength * 100)
                            color: theme.textMuted
                            font.family: runtime.fontMono
                            font.pixelSize: theme.fontSize(8)
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        width: 100
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: modelData.stateChanging ? ConnectionState.toString(modelData.state).toUpperCase() : (modelData.connected ? "ENTER // DROP" : "ENTER // JOIN")
                        color: modelData.stateChanging ? theme.warning : theme.accent
                        font.family: runtime.fontMono
                        font.pixelSize: theme.fontSize(8)
                        font.weight: Font.DemiBold
                    }
                }

                Connections {
                    target: modelData

                    function onConnectionFailed(reason): void {
                        if (reason === ConnectionFailReason.NoSecrets && panel.supportsPsk(modelData)) {
                            panel.promptForPassword(modelData, "AUTH REQUIRED // " + modelData.name);
                            return;
                        }

                        panel.statusText = ConnectionFailReason.toString(reason).toUpperCase();
                        panel.statusError = true;
                        panel.keyboardRequested();
                    }

                    function onConnectedChanged(): void {
                        if (modelData.connected) {
                            panel.statusText = "CONNECTED // " + modelData.name;
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
            spacing: theme.spacing3

            Text {
                width: parent.width
                text: pendingNetwork ? pendingNetwork.name : ""
                horizontalAlignment: Text.AlignHCenter
                color: theme.textStrong
                font.family: runtime.fontSans
                font.pixelSize: theme.fontSize(18)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: pendingNetwork ? WifiSecurityType.toString(pendingNetwork.security).toUpperCase() : ""
                horizontalAlignment: Text.AlignHCenter
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(9)
                font.letterSpacing: 1
            }

            SquircleSurface {
                width: parent.width
                height: 50
                exponent: theme.squircleExponent
                cornerRadius: theme.radiusMedium
                fillColor: theme.background
                borderColor: passwordInput.activeFocus ? theme.accent : theme.outline
                borderWidth: passwordInput.activeFocus ? theme.borderFocus : theme.borderThin

                TextInput {
                    id: passwordInput

                    anchors {
                        fill: parent
                        leftMargin: theme.spacing4
                        rightMargin: theme.spacing4
                    }

                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                    color: theme.textStrong
                    selectionColor: theme.accent
                    selectedTextColor: theme.background
                    font.family: runtime.fontSans
                    font.pixelSize: theme.fontSize(15)
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
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(8)
                font.letterSpacing: 0.8
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !system.wifiAvailable && !panel.passwordPrompt
            width: parent.width
            text: system.networkConnected ? "WIRED LINK // " + system.networkName : "NO WI-FI DEVICE // NETWORK OFFLINE"
            horizontalAlignment: Text.AlignHCenter
            color: system.networkConnected ? theme.text : theme.textMuted
            font.family: runtime.fontMono
            font.pixelSize: theme.fontSize(10)
            font.letterSpacing: 0.8
        }

        Text {
            anchors.centerIn: parent
            visible: system.wifiAvailable && !system.wifiEnabled && !panel.passwordPrompt
            width: parent.width
            text: system.wifiHardwareEnabled ? "WI-FI RADIO DISABLED // PRESS W" : "WI-FI DISABLED BY HARDWARE"
            horizontalAlignment: Text.AlignHCenter
            color: system.wifiHardwareEnabled ? theme.warning : theme.critical
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
            visible: panel.statusText.length > 0
            text: panel.statusText
            horizontalAlignment: Text.AlignHCenter
            color: panel.statusError ? theme.critical : theme.accent
            font.family: runtime.fontMono
            font.pixelSize: theme.fontSize(8)
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
            elide: Text.ElideRight
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: theme.spacing4

            Text {
                visible: system.wifiAvailable
                text: "↑↓  SELECT   ENTER  JOIN/DROP"
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(8)
                font.letterSpacing: 0.8
            }

            Text {
                visible: system.wifiAvailable
                text: "W  WI-FI"
                color: theme.accent
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(8)
                font.letterSpacing: 0.8
            }

            Text {
                text: "A  ADVANCED"
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(8)
                font.letterSpacing: 0.8
            }

            Text {
                text: "ESC  BACK"
                color: theme.textMuted
                font.family: runtime.fontMono
                font.pixelSize: theme.fontSize(8)
                font.letterSpacing: 0.8
            }
        }
    }
}
