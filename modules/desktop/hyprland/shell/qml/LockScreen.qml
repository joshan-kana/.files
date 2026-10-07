import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland

WlSessionLock {
    id: lock

    required property QtObject runtime
    required property QtObject theme
    required property QtObject motion

    property string password: ""
    property string statusText: ""
    property bool statusError: false

    property PamContext pamContext: PamContext {
        config: "linux-desktop"

        onPamMessage: {
            if (!responseRequired) {
                if (message.length > 0) {
                    lock.statusText = message;
                    lock.statusError = messageIsError;
                }
                return;
            }

            if (lock.password.length === 0) {
                lock.statusText = message.length > 0 ? message : "PASSWORD REQUIRED";
                lock.statusError = messageIsError;
                return;
            }

            const response = lock.password;
            lock.password = "";
            pamContext.respond(response);
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                lock.password = "";
                lock.statusText = "";
                lock.statusError = false;
                lock.locked = false;
                return;
            }

            lock.password = "";
            lock.statusError = true;

            if (result === PamResult.MaxTries)
                lock.statusText = "TOO MANY ATTEMPTS";
            else if (result === PamResult.Error)
                lock.statusText = "AUTHENTICATION ERROR";
            else
                lock.statusText = "AUTHENTICATION FAILED";
        }

        onError: error => {
            lock.password = "";
            lock.statusError = true;
            lock.statusText = PamError.toString(error).toUpperCase();
        }
    }

    property SystemClock clock: SystemClock {
        precision: SystemClock.Seconds
    }

    readonly property bool authenticating: pamContext.active

    function lockSession(): void {
        if (locked)
            return;

        if (pamContext.active)
            pamContext.abort();

        password = "";
        statusText = "";
        statusError = false;
        locked = true;
    }

    function submitPassword(): void {
        if (!locked || authenticating || password.length === 0)
            return;

        statusText = "VERIFYING";
        statusError = false;

        if (!pamContext.start()) {
            password = "";
            statusText = "AUTHENTICATION UNAVAILABLE";
            statusError = true;
        }
    }

    onLockStateChanged: {
        if (locked)
            return;

        if (pamContext.active)
            pamContext.abort();

        password = "";
        statusText = "";
        statusError = false;
    }

    WlSessionLockSurface {
        color: lock.theme.background

        Item {
            anchors.fill: parent

            Image {
                anchors.fill: parent
                source: lock.runtime.wallpaper
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
            }

            Rectangle {
                anchors.fill: parent
                color: theme.scrimStrong
            }

            Rectangle {
                anchors {
                    top: parent.top
                    right: parent.right
                    bottom: parent.bottom
                    left: parent.left
                }

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.rgba(lock.theme.background.r, lock.theme.background.g, lock.theme.background.b, 0.12)
                    }
                    GradientStop {
                        position: 0.62
                        color: Qt.rgba(lock.theme.background.r, lock.theme.background.g, lock.theme.background.b, 0.38)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.rgba(lock.theme.background.r, lock.theme.background.g, lock.theme.background.b, 0.76)
                    }
                }
            }

            Column {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    topMargin: Math.max(70, parent.height * 0.13)
                }
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(lock.clock.date, "HH:mm")
                    color: lock.theme.textStrong
                    font.family: lock.runtime.fontMono
                    font.pixelSize: theme.fontSize(Math.max(62, Math.min(104, parent.parent.width * 0.055)))
                    font.weight: Font.Light
                    font.letterSpacing: -2
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(lock.clock.date, "dddd, d MMMM").toUpperCase()
                    color: lock.theme.textMuted
                    font.family: lock.runtime.fontMono
                    font.pixelSize: theme.fontSize(11)
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2
                }
            }

            SquircleSurface {
                id: authCard

                width: Math.min(parent.width - 80, 430)
                height: contentColumn.implicitHeight + lock.theme.spacing5 * 2
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: Math.max(70, parent.height * 0.11)
                }

                exponent: lock.theme.squircleExponent
                cornerRadius: lock.theme.radiusPanel
                fillColor: Qt.rgba(lock.theme.surface.r, lock.theme.surface.g, lock.theme.surface.b, 0.94)
                borderColor: lock.theme.panelBorder
                borderWidth: lock.theme.borderThin

                Item {
                    anchors.fill: parent
                    anchors.margins: lock.theme.spacing5

                    Column {
                        id: contentColumn

                        width: parent.width
                        spacing: lock.theme.spacing3

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: lock.theme.spacing1

                            Image {
                                width: 44
                                height: 44
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: Quickshell.iconPath("system-lock-screen")
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Quickshell.env("USER") || "user"
                                color: lock.theme.textStrong
                                font.family: lock.runtime.fontMono
                                font.pixelSize: theme.fontSize(18)
                                font.weight: Font.DemiBold
                            }
                        }

                        SquircleSurface {
                            width: parent.width
                            height: 54

                            exponent: lock.theme.squircleExponent
                            cornerRadius: lock.theme.radiusMedium
                            fillColor: lock.theme.background
                            borderColor: passwordInput.activeFocus ? lock.theme.accent : lock.theme.outline
                            borderWidth: passwordInput.activeFocus ? lock.theme.borderFocus : lock.theme.borderThin

                            TextInput {
                                id: passwordInput

                                anchors {
                                    fill: parent
                                    leftMargin: lock.theme.spacing4
                                    rightMargin: lock.theme.spacing4
                                }

                                enabled: !lock.authenticating
                                focus: true
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                passwordCharacter: "●"
                                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                                color: lock.theme.textStrong
                                selectionColor: lock.theme.accent
                                selectedTextColor: lock.theme.background
                                font.family: lock.runtime.fontMono
                                font.pixelSize: theme.fontSize(17)
                                clip: true

                                onTextEdited: lock.password = text

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        lock.submitPassword();
                                        event.accepted = true;
                                    } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U) {
                                        lock.password = "";
                                        text = "";
                                        event.accepted = true;
                                    }
                                }

                                Component.onCompleted: forceActiveFocus()

                                Connections {
                                    target: lock

                                    function onPasswordChanged(): void {
                                        if (passwordInput.text !== lock.password)
                                            passwordInput.text = lock.password;

                                        if (!lock.authenticating)
                                            passwordInput.forceActiveFocus();
                                    }
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            height: 18
                            text: lock.statusText.length > 0 ? lock.statusText : (lock.authenticating ? "AUTHENTICATING" : "ENTER PASSWORD")
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: lock.statusError ? lock.theme.critical : lock.theme.textMuted
                            font.family: lock.runtime.fontMono
                            font.pixelSize: theme.fontSize(9)
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
