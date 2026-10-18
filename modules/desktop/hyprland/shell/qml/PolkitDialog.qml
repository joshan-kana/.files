pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland

Scope {
    id: auth
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    required property ScreenRouter screens

    // qmllint disable unresolved-type
    readonly property var flow: agent["flow"]
    // qmllint enable unresolved-type
    property bool submitting: false

    function clearEntry(): void {
        credential.text = "";
        submitting = false;
    }

    function submit(): void {
        if (!flow || !flow.isResponseRequired || submitting)
            return;
        const response = credential.text;
        // Passwords are passed only to the Polkit conversation, never to a
        // subprocess, command line, clipboard, filesystem or status message.
        credential.text = "";
        submitting = true;
        flow.submit(response);
    }

    function cancel(): void {
        clearEntry();
        if (flow)
            flow.cancelAuthenticationRequest();
    }

    function switchIdentity(): void {
        if (!flow || flow.identities.length < 2)
            return;
        const index = flow.identities.indexOf(flow.selectedIdentity);
        clearEntry();
        flow.selectedIdentity = flow.identities[(index + 1) % flow.identities.length];
    }

    PolkitAgent {
        id: agent
        onFlowChanged: {
            auth.clearEntry();
            if (auth.flow)
                Qt.callLater(() => credential.forceActiveFocus());
        }
    }

    Connections {
        target: auth.flow
        ignoreUnknownSignals: true
        function onIsResponseRequiredChanged(): void {
            auth.clearEntry();
            if (auth.flow && auth.flow.isResponseRequired)
                Qt.callLater(() => credential.forceActiveFocus());
        }
        function onAuthenticationFailed(): void {
            auth.clearEntry();
            Qt.callLater(() => credential.forceActiveFocus());
        }
        function onAuthenticationRequestCancelled(): void {
            auth.clearEntry();
        }
    }

    PanelWindow {
        id: popup
        screen: auth.screens.focusedScreen
        visible: agent.isActive
        focusable: agent.isActive
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            right: true
            bottom: true
            left: true
        }
        WlrLayershell.namespace: "linux-desktop-authentication"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: agent.isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: auth.theme.scrimStrong
            opacity: 0.88
        }

        ShellSurface {
            id: authenticationCard
            anchors.centerIn: parent
            width: Math.min(470, Math.max(280, popup.width - 48))
            height: body.implicitHeight + auth.theme.spacing5 * 2
            theme: auth.theme
            motion: auth.motion
            surfaceLayer: ShellSurface.Pane
            cornerRadius: auth.theme.radiusPanel
            fillColor: auth.theme.expressiveSurface
            elevated: true
            outlined: true

            Column {
                id: body
                width: parent.width - auth.theme.spacing5 * 2
                anchors.centerIn: parent
                spacing: auth.theme.spacing3

                Row {
                    width: parent.width
                    spacing: auth.theme.spacing3
                    Text {
                        text: "󰒃"
                        color: auth.theme.warning
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: auth.theme.fontSize(30)
                    }
                    Column {
                        spacing: 4
                        Text {
                            text: "AUTHENTICATION"
                            color: auth.theme.warning
                            font.family: auth.runtime.fontMono
                            font.pixelSize: auth.theme.fontSize(10)
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2
                        }
                        Text {
                            text: "Authorization required"
                            color: auth.theme.textStrong
                            font.family: auth.runtime.fontMono
                            font.pixelSize: auth.theme.fontSize(18)
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: auth.flow ? auth.flow.message : ""
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    color: auth.theme.text
                    font.family: auth.runtime.fontMono
                    font.pixelSize: auth.theme.fontSize(12)
                }
                MarqueeText {
                    width: parent.width
                    text: auth.flow ? auth.flow.actionId : ""
                    color: auth.theme.textMuted
                    font.family: auth.runtime.fontMono
                    font.pixelSize: auth.theme.fontSize(9)
                }

                Row {
                    width: parent.width
                    spacing: auth.theme.spacing2
                    MarqueeText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(1, parent.width - (identityButton.visible ? identityButton.width + parent.spacing : 0))
                        text: "󰀄  " + (auth.flow && auth.flow.selectedIdentity ? auth.flow.selectedIdentity.displayName : "Local authentication")
                        color: auth.theme.textStrong
                        font.family: auth.runtime.fontMono
                        font.pixelSize: auth.theme.fontSize(11)
                    }
                    ShellAction {
                        id: identityButton
                        visible: !!auth.flow && auth.flow.identities.length > 1
                        width: 96
                        height: 31
                        runtime: auth.runtime
                        theme: auth.theme
                        motion: auth.motion
                        compact: true
                        horizontalCompact: true
                        title: "IDENTITY"
                        shortcut: "I"
                        onActivated: auth.switchIdentity()
                    }
                }
                Text {
                    width: parent.width
                    text: auth.flow && auth.flow.inputPrompt.length ? auth.flow.inputPrompt : "Password"
                    textFormat: Text.PlainText
                    color: auth.theme.textMuted
                    font.family: auth.runtime.fontMono
                    font.pixelSize: auth.theme.fontSize(10)
                }

                ShellSurface {
                    id: credentialSurface
                    width: parent.width
                    height: 46
                    theme: auth.theme
                    motion: auth.motion
                    surfaceLayer: ShellSurface.Control
                    cornerRadius: auth.theme.radiusMedium
                    outlined: credential.activeFocus || auth.submitting
                    borderColor: credential.activeFocus || auth.submitting ? auth.theme.accent : auth.theme.subtleBorder

                    TextInput {
                        id: credential
                        anchors {
                            fill: parent
                            margins: auth.theme.spacing3
                        }
                        verticalAlignment: TextInput.AlignVCenter
                        enabled: !!auth.flow && auth.flow.isResponseRequired && !auth.submitting
                        color: auth.theme.textStrong
                        selectionColor: auth.theme.accent
                        font.family: auth.runtime.fontMono
                        font.pixelSize: auth.theme.fontSize(13)
                        echoMode: auth.flow && auth.flow.responseVisible ? TextInput.Normal : TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                auth.cancel();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                auth.submit();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_I && (event.modifiers & Qt.ControlModifier)) {
                                auth.switchIdentity();
                                event.accepted = true;
                            }
                        }
                    }

                    LoadingOutline {
                        anchors.fill: parent
                        surface: credentialSurface
                        active: auth.submitting
                        motionEnabled: auth.motion.enabled
                        highlightColor: auth.theme.warning
                        lineWidth: 2
                    }
                }

                Text {
                    width: parent.width
                    visible: !!auth.flow && (auth.flow.failed || auth.flow.supplementaryMessage.length > 0)
                    text: auth.flow ? (auth.flow.supplementaryMessage.length > 0 ? auth.flow.supplementaryMessage : "Authentication failed. Retry or cancel.") : ""
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    color: auth.flow && (auth.flow.supplementaryIsError || auth.flow.failed) ? auth.theme.critical : auth.theme.textMuted
                    font.family: auth.runtime.fontMono
                    font.pixelSize: auth.theme.fontSize(10)
                }

                Row {
                    width: parent.width
                    spacing: auth.theme.spacing3
                    ShellAction {
                        width: (parent.width - parent.spacing) / 2
                        height: 42
                        runtime: auth.runtime
                        theme: auth.theme
                        motion: auth.motion
                        compact: true
                        horizontalCompact: true
                        icon: "󰅖"
                        title: "CANCEL"
                        shortcut: "ESC"
                        onActivated: auth.cancel()
                    }
                    ShellAction {
                        width: (parent.width - parent.spacing) / 2
                        height: 42
                        runtime: auth.runtime
                        theme: auth.theme
                        motion: auth.motion
                        compact: true
                        horizontalCompact: true
                        icon: "󰄬"
                        title: auth.submitting ? "VERIFYING" : "AUTHORIZE"
                        shortcut: "ENTER"
                        enabled: !!auth.flow && auth.flow.isResponseRequired && !auth.submitting
                        active: true
                        activeColor: auth.theme.warning
                        onActivated: auth.submit()
                    }
                }
            }
        }
    }
}
