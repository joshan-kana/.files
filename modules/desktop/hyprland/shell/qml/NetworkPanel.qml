pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
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

    // NetworkManager remains the owner of saved profiles. Query only on entry
    // and after an explicit operation, never poll while Controls is idle.
    property bool savedView: false
    property var savedProfiles: []
    property int savedIndex: 0
    property string actionUuid: ""
    property bool detailView: false
    property bool detailConnected: false
    property string detailName: ""
    property string detailDevice: ""
    property string detailType: ""
    property string detailUuid: ""
    property var detailRows: []
    property var detailBaseRows: []
    property bool detailError: false
    property string profileQueryUuid: ""
    readonly property bool detailPending: detailProcess.running || profileDetailsProcess.running

    property StdioCollector profileDetailsOutput: StdioCollector {}
    property Process profileDetailsProcess: Process {
        stdout: panel.profileDetailsOutput
        onExited: (exitCode, exitStatus) => {
            if (!panel.detailView || panel.detailConnected || panel.profileQueryUuid !== panel.detailUuid)
                return;
            panel.detailError = exitCode !== 0;
            panel.detailRows = panel.detailBaseRows.concat(exitCode === 0 ? panel.parseProfileDetails(panel.profileDetailsOutput.text) : [
                {
                    label: "CONFIG STATUS",
                    value: "SAVED PROFILE NO LONGER AVAILABLE"
                }
            ]);
        }
    }

    function parseProfileDetails(source: string): var {
        // Never request or render credentials, PSKs, keys or VPN secrets.
        // These are saved configuration values, not live interface addresses.
        const allowed = {
            "connection.interface-name": "DEVICE CONFIG",
            "connection.autoconnect": "AUTO CONNECT",
            "ipv4.method": "IPv4 MODE",
            "ipv4.addresses": "IPv4 CONFIG",
            "ipv4.gateway": "GATEWAY CONFIG",
            "ipv4.dns": "DNS CONFIG",
            "ipv6.method": "IPv6 MODE",
            "ipv6.addresses": "IPv6 CONFIG",
            "ipv6.gateway": "IPv6 GATEWAY",
            "ipv6.dns": "IPv6 DNS"
        };
        const values = {};
        for (const line of source.split("\n")) {
            const fields = splitNmcli(line);
            const key = fields[0];
            const value = fields.slice(1).join(":").trim();
            if (Object.prototype.hasOwnProperty.call(allowed, key) && value && value !== "--")
                values[key] = value;
        }
        return Object.keys(allowed).filter(key => values[key]).map(key => ({
                    label: allowed[key],
                    value: values[key]
                }));
    }

    property StdioCollector detailOutput: StdioCollector {}
    property Process detailProcess: Process {
        stdout: panel.detailOutput
        onExited: (exitCode, exitStatus) => {
            if (!panel.detailView)
                return;
            if (exitCode !== 0) {
                panel.detailError = true;
                return;
            }
            panel.detailRows = panel.parseLinkDetails(panel.detailOutput.text);
            panel.detailError = panel.detailRows.length === 0;
        }
    }

    function parseLinkDetails(source: string): var {
        const all = [];
        let info = null;
        for (const line of source.split("\n")) {
            const fields = splitNmcli(line);
            if (fields.length < 2)
                continue;
            const field = fields[0].replace(/\[\d+\]$/, "");
            const value = fields.slice(1).join(":").trim();
            if (field === "GENERAL.DEVICE") {
                info = {
                    name: value,
                    properties: {}
                };
                all.push(info);
            }
            if (info && value.length > 0) {
                if (!info.properties[field])
                    info.properties[field] = [];
                info.properties[field].push(value);
            }
        }
        const current = all.find(device => device.name === detailDevice) || all.find(device => (device.properties["GENERAL.CONNECTION"] || []).includes(detailName)) || (detailDevice.length === 0 ? all.find(device => (device.properties["GENERAL.STATE"] || []).some(value => value.startsWith("100"))) : null);
        if (!current)
            return [];
        const values = current.properties;
        const result = [];
        const add = (label, property, maximum) => {
            const matches = (values[property] || []).slice(0, maximum);
            if (matches.length > 0)
                result.push({
                    label,
                    value: matches.join(" · ")
                });
        };
        add("DEVICE", "GENERAL.DEVICE", 1);
        add("CONNECTION", "GENERAL.CONNECTION", 1);
        add("STATUS", "GENERAL.STATE", 1);
        add("IPv4", "IP4.ADDRESS", 2);
        add("GATEWAY", "IP4.GATEWAY", 1);
        add("DNS", "IP4.DNS", 3);
        add("IPv6", "IP6.ADDRESS", 2);
        add("IPv6 GATEWAY", "IP6.GATEWAY", 1);
        add("IPv6 DNS", "IP6.DNS", 2);
        add("MAC", "GENERAL.HWADDR", 1);
        add("MTU", "GENERAL.MTU", 1);
        return result;
    }

    function refreshDetails(): void {
        if (!detailView || runtime.nmcli.length === 0)
            return;
        detailError = false;
        if (!detailConnected) {
            if (detailUuid.length === 0 || profileDetailsProcess.running)
                return;
            profileQueryUuid = detailUuid;
            profileDetailsProcess.exec([runtime.nmcli, "--escape", "yes", "-t", "-f", "connection.interface-name,connection.autoconnect,ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns,ipv6.method,ipv6.addresses,ipv6.gateway,ipv6.dns", "connection", "show", "uuid", detailUuid]);
            return;
        }
        if (!detailProcess.running)
            detailProcess.exec([runtime.nmcli, "--escape", "yes", "-t", "-f", "GENERAL.DEVICE,GENERAL.CONNECTION,GENERAL.STATE,GENERAL.HWADDR,GENERAL.MTU,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,IP6.GATEWAY,IP6.DNS", "device", "show"]);
    }

    function toggleDetailView(): void {
        if (passwordPrompt)
            return;
        if (detailView) {
            detailView = false;
            detailRows = [];
            detailBaseRows = [];
            keyboardRequested();
            return;
        }
        const profile = savedView ? savedSelected : selectedNetwork();
        detailName = profile ? profile.name : system.networkName;
        detailDevice = savedView && profile && profile.connected ? profile.device : "";
        detailType = savedView && profile ? profile.label : system.wifiAvailable ? "WI-FI" : "WIRED";
        detailUuid = savedView && profile ? profile.uuid : "";
        detailConnected = profile ? Boolean(profile.connected) : system.networkConnected;
        detailRows = detailConnected ? [] : [
            {
                label: "PROFILE",
                value: detailName || "UNAVAILABLE"
            },
            {
                label: "TYPE",
                value: detailType
            },
            {
                label: "STATUS",
                value: "DISCONNECTED"
            },
            {
                label: "UUID",
                value: detailUuid || "NO PROFILE"
            }
        ];
        detailBaseRows = detailRows;
        detailError = false;
        detailView = true;
        refreshDetails();
        keyboardRequested();
    }

    readonly property bool actionBusy: profileAction.running
    readonly property var savedSelected: savedProfiles.length > 0 ? savedProfiles[Math.max(0, Math.min(savedIndex, savedProfiles.length - 1))] : null

    property StdioCollector profilesOutput: StdioCollector {}
    property StdioCollector profileError: StdioCollector {}
    property Process profilesQuery: Process {
        stdout: panel.profilesOutput
        stderr: panel.profileError
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                panel.savedProfiles = panel.parseProfiles(panel.profilesOutput.text);
                panel.savedIndex = Math.min(panel.savedIndex, Math.max(0, panel.savedProfiles.length - 1));
            } else {
                panel.statusText = "SAVED PROFILES UNAVAILABLE";
                panel.statusError = true;
            }
        }
    }

    property StdioCollector actionError: StdioCollector {}
    property Process profileAction: Process {
        stderr: panel.actionError
        onExited: (exitCode, exitStatus) => {
            panel.statusText = exitCode === 0 ? "CONNECTION UPDATED" : "CONNECTION FAILED // " + panel.actionError.text.trim().slice(0, 115);
            panel.statusError = exitCode !== 0;
            panel.actionUuid = "";
            panel.refreshSaved();
            if (panel.detailView)
                panel.refreshDetails();
        }
    }

    function splitNmcli(line: string): var {
        const fields = [];
        let current = "";
        let escapeNext = false;
        for (const character of line) {
            if (escapeNext) {
                current += character;
                escapeNext = false;
            } else if (character === "\\") {
                escapeNext = true;
            } else if (character === ":") {
                fields.push(current);
                current = "";
            } else {
                current += character;
            }
        }
        fields.push(current);
        return fields;
    }

    function parseProfiles(output: string): var {
        const parsed = [];
        for (const line of output.split("\n")) {
            const fields = splitNmcli(line);
            if (fields.length !== 4 || !/^[a-f0-9-]{36}$/i.test(fields[0]))
                continue;
            const kind = fields[1];
            const supported = kind === "802-11-wireless" || kind === "vpn" || kind === "wireguard";
            const label = kind === "802-11-wireless" ? "WI-FI" : kind === "802-3-ethernet" ? "ETHERNET" : kind === "wireguard" || kind === "vpn" ? "VPN" : "SYSTEM";
            parsed.push({
                uuid: fields[0],
                kind,
                name: fields[2],
                device: fields[3],
                connected: fields[3] !== "--" && fields[3].length > 0,
                label,
                supported
            });
        }
        return parsed.slice(0, 100);
    }

    function refreshSaved(): void {
        if (runtime.nmcli.length > 0 && !profilesQuery.running)
            profilesQuery.exec([runtime.nmcli, "--escape", "yes", "-t", "-f", "UUID,TYPE,NAME,DEVICE", "connection", "show"]);
    }

    function toggleSavedView(): void {
        if (passwordPrompt)
            return;
        detailView = false;
        savedView = !savedView;
        statusText = "";
        statusError = false;
        if (savedView)
            refreshSaved();
        keyboardRequested();
    }

    function activateSaved(): void {
        const profile = savedSelected;
        if (!profile || !profile.supported || actionBusy || runtime.nmcli.length === 0)
            return;
        const action = profile.connected ? "down" : "up";
        actionUuid = profile.uuid;
        statusText = (profile.connected ? "DISCONNECTING // " : "CONNECTING // ") + profile.name;
        statusError = false;
        profileAction.exec([runtime.nmcli, "connection", action, "uuid", profile.uuid]);
    }

    readonly property var networks: system.wifiNetworks || []
    readonly property bool passwordPrompt: pendingNetwork !== null

    implicitHeight: header.height + panel.theme.spacing3 * 2 + (detailView ? Math.min(448, Math.max(252, detailPending ? 448 : detailRows.length * 60 + 16)) : savedView ? Math.min(430, Math.max(185, savedProfiles.length * 76)) : system.wifiAvailable && system.wifiEnabled ? Math.min(430, Math.max(185, networks.length * 96)) : 188) + footer.implicitHeight + panel.theme.spacing4
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
        savedView = false;
        detailView = false;
        savedIndex = 0;

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
        savedView = false;
        detailView = false;
        detailRows = [];
        detailBaseRows = [];
        open = false;
        keyboardRequested();
    }

    function moveHalfPage(direction: int): void {
        if (detailView) {
            detailList.contentY = Math.max(0, Math.min(detailList.contentHeight - detailList.height, detailList.contentY + direction * detailList.height / 2));
            return;
        }
        if (savedView) {
            savedIndex = Math.max(0, Math.min(savedProfiles.length - 1, savedIndex + direction * 4));
            return;
        }
        const rowHeight = networkList.currentItem ? networkList.currentItem.height + networkList.spacing : 64;
        const rows = Math.max(1, Math.floor(networkList.height / Math.max(1, rowHeight) / 2));
        moveSelection(direction * rows);
    }

    function moveSelection(delta: int): void {
        if (detailView) {
            detailList.contentY = Math.max(0, Math.min(detailList.contentHeight - detailList.height, detailList.contentY + delta * 64));
            return;
        }
        if (savedView) {
            savedIndex = Math.max(0, Math.min(savedProfiles.length - 1, savedIndex + delta));
            return;
        }
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
        if (detailView)
            return;
        if (savedView) {
            activateSaved();
            return;
        }
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

    DetailHero {
        id: header
        width: parent.width
        height: implicitHeight
        runtime: panel.runtime
        theme: panel.theme
        motion: panel.motion
        glyph: panel.detailView ? "󰋼" : panel.system.wifiConnected ? "󰤨" : panel.system.networkConnected ? "󰈀" : "󰤭"
        glyphColor: panel.system.networkConnected ? panel.theme.positive : panel.theme.warning
        eyebrow: "Connectivity / " + panel.system.connectivityText
        title: panel.detailView ? "Connection details" : panel.savedView ? "Saved connections" : panel.system.wifiAvailable ? "Wi-Fi" : "Network"
        detail: panel.detailView ? panel.detailName + " · " + panel.detailType : panel.savedView ? panel.savedProfiles.length + " NetworkManager profiles · VPN / Wi-Fi" : panel.system.networkConnected ? panel.system.networkName : "No active network"
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
            visible: !panel.detailView && !panel.savedView && panel.system.wifiAvailable && panel.system.wifiEnabled && !panel.passwordPrompt
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
                height: 88
                theme: panel.theme
                motion: panel.motion
                surfaceLayer: ShellSurface.Control
                selected: index === panel.selectedIndex
                cornerRadius: theme.radiusLarge
                fillColor: networkRow.modelData.connected ? panel.theme.blend(panel.theme.groupBase, panel.theme.positive, panel.theme.dark ? 0.11 : 0.07) : panel.theme.layer3

                StateLayer {
                    theme: panel.theme
                    motion: panel.motion
                    selected: networkRow.index === panel.selectedIndex
                    cornerRadius: panel.theme.radiusLarge
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

                            MarqueeText {
                                width: parent.width - statusBadge.width - parent.spacing
                                text: networkRow.modelData.name
                                color: panel.theme.textStrong
                                font.family: panel.runtime.fontMono
                                font.pixelSize: panel.theme.fontSize(13)
                                font.weight: networkRow.modelData.connected ? Font.DemiBold : Font.Normal
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

        ListView {
            id: savedList
            anchors.fill: parent
            visible: panel.savedView && !panel.detailView
            model: panel.savedProfiles
            currentIndex: panel.savedIndex
            spacing: panel.theme.spacing2
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: ShellSurface {
                id: profileRow
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 68
                theme: panel.theme
                motion: panel.motion
                surfaceLayer: ShellSurface.Control
                cornerRadius: theme.radiusMedium
                selected: index === panel.savedIndex

                StateLayer {
                    theme: panel.theme
                    motion: panel.motion
                    cornerRadius: panel.theme.radiusMedium
                    selected: profileRow.index === panel.savedIndex
                    onActivated: {
                        panel.savedIndex = profileRow.index;
                        panel.activateSaved();
                    }
                }

                Row {
                    anchors {
                        fill: parent
                        margins: panel.theme.spacing3
                    }
                    spacing: panel.theme.spacing3
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 76
                        text: profileRow.modelData.label
                        color: profileRow.modelData.connected ? panel.theme.positive : panel.theme.accent
                        font.family: panel.runtime.fontMono
                        font.pixelSize: panel.theme.fontSize(9)
                        font.weight: Font.DemiBold
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(1, parent.width - 76 - statusLabel.width - parent.spacing * 2)
                        spacing: panel.theme.spacing1
                        Text {
                            width: parent.width
                            text: profileRow.modelData.name
                            elide: Text.ElideRight
                            color: panel.theme.textStrong
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(12)
                            font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            text: profileRow.modelData.connected ? "ACTIVE / " + profileRow.modelData.device : profileRow.modelData.kind.toUpperCase()
                            elide: Text.ElideRight
                            color: panel.theme.textMuted
                            font.family: panel.runtime.fontMono
                            font.pixelSize: panel.theme.fontSize(9)
                        }
                    }
                    Text {
                        id: statusLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.actionUuid === profileRow.modelData.uuid ? "WORKING" : !profileRow.modelData.supported ? "DETAILS ONLY" : profileRow.modelData.connected ? "ENTER / DROP" : "ENTER / JOIN"
                        color: panel.actionUuid === profileRow.modelData.uuid ? panel.theme.warning : profileRow.modelData.connected ? panel.theme.positive : panel.theme.textMuted
                        font.family: panel.runtime.fontMono
                        font.pixelSize: panel.theme.fontSize(9)
                    }
                }
            }
        }

        ListView {
            id: detailList
            anchors.fill: parent
            visible: panel.detailView
            model: panel.detailRows
            spacing: panel.theme.spacing2
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            delegate: ShellSurface {
                id: detailRow
                required property var modelData
                width: ListView.view.width
                height: 52
                theme: panel.theme
                motion: panel.motion
                surfaceLayer: ShellSurface.Control
                cornerRadius: panel.theme.radiusMedium
                Row {
                    anchors {
                        fill: parent
                        margins: panel.theme.spacing3
                    }
                    spacing: panel.theme.spacing3
                    Text {
                        width: 115
                        anchors.verticalCenter: parent.verticalCenter
                        text: detailRow.modelData.label
                        color: panel.theme.accent
                        font.family: panel.runtime.fontMono
                        font.pixelSize: panel.theme.fontSize(10)
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(1, parent.width - 115 - parent.spacing)
                        text: detailRow.modelData.value
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        color: detailRow.modelData.label === "CONFIG STATUS" ? panel.theme.warning : panel.theme.textStrong
                        font.family: panel.runtime.fontMono
                        font.pixelSize: panel.theme.fontSize(11)
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            visible: panel.detailView && panel.detailRows.length === 0
            spacing: panel.theme.spacing3
            width: parent.width
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: panel.detailPending ? "READING NETWORKMANAGER…" : panel.detailError ? "CONNECTION DETAILS UNAVAILABLE" : "NO ACTIVE INTERFACE"
                color: panel.detailError ? panel.theme.warning : panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(10)
            }
            Text {
                width: parent.width
                text: panel.detailUuid.length ? "PROFILE  " + panel.detailUuid : "DETAILS ARE READ-ONLY"
                color: panel.theme.textMuted
                font.family: panel.runtime.fontMono
                font.pixelSize: panel.theme.fontSize(9)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
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

            KeyHintStrip {
                width: parent.width
                runtime: panel.runtime
                theme: panel.theme
                hints: [
                    {
                        shortcut: "ENTER",
                        label: "Connect"
                    },
                    {
                        shortcut: "ESC",
                        label: "Cancel"
                    }
                ]
            }
        }

        ShellSurface {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: 160
            visible: !panel.detailView && !panel.savedView && !panel.system.wifiAvailable && !panel.passwordPrompt
            theme: panel.theme
            motion: panel.motion
            surfaceLayer: ShellSurface.Group
            cornerRadius: panel.theme.radiusLarge

            Column {
                width: parent.width - panel.theme.spacing5 * 2
                anchors.centerIn: parent
                spacing: panel.theme.spacing3

                Text {
                    text: panel.system.networkConnected ? "WIRED CONNECTION" : "NO ACTIVE CONNECTION"
                    color: panel.system.networkConnected ? panel.theme.positive : panel.theme.warning
                    font.family: panel.runtime.fontMono
                    font.pixelSize: panel.theme.fontSize(11)
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    text: panel.system.networkName
                    color: panel.theme.textStrong
                    font.family: panel.runtime.fontMono
                    font.pixelSize: panel.theme.fontSize(20)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: "No Wi-Fi adapter is available on this host."
                    color: panel.theme.textMuted
                    font.family: panel.runtime.fontMono
                    font.pixelSize: panel.theme.fontSize(10)
                    wrapMode: Text.WordWrap
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !panel.detailView && !panel.savedView && panel.system.wifiAvailable && !panel.system.wifiEnabled && !panel.passwordPrompt
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
            width: parent.width
            spacing: panel.theme.spacing2
            KeyHintStrip {
                width: Math.max(1, parent.width - detailsButton.width - parent.spacing)
                runtime: panel.runtime
                theme: panel.theme
                hints: [
                    {
                        shortcut: "J/K",
                        label: "Select",
                        visible: !panel.detailView && (panel.savedView || panel.system.wifiAvailable)
                    },
                    {
                        shortcut: "ENTER",
                        label: "Connect",
                        visible: !panel.detailView && (panel.savedView || panel.system.wifiAvailable)
                    },
                    {
                        shortcut: "W",
                        label: "Wi-Fi",
                        visible: !panel.detailView && !panel.savedView && panel.system.wifiAvailable
                    },
                    {
                        shortcut: "P",
                        label: panel.savedView ? "Scan" : "Saved",
                        visible: !panel.detailView
                    },
                    {
                        shortcut: "R",
                        label: "Refresh",
                        visible: panel.savedView || panel.detailView
                    },
                    {
                        shortcut: "J/K",
                        label: "Scroll",
                        visible: panel.detailView
                    },
                    {
                        shortcut: "A",
                        label: "Advanced"
                    },
                    {
                        shortcut: "ESC",
                        label: "Back"
                    }
                ]
            }
            ShellAction {
                id: detailsButton
                width: 116
                height: 40
                runtime: panel.runtime
                theme: panel.theme
                motion: panel.motion
                compact: true
                horizontalCompact: true
                icon: panel.detailView ? "󰅌" : "󰋼"
                title: panel.detailView ? "Back" : "Details"
                shortcut: "I"
                active: panel.detailView
                onActivated: panel.toggleDetailView()
            }
        }
    }
}
