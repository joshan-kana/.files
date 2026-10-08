pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland

WlSessionLock {
    id: lock

    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion

    property string password: ""
    property string statusText: ""
    property bool statusError: false
    property bool authRevealed: false

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
            lock.pamContext.respond(response);
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
        authRevealed = false;
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
        authRevealed = false;
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
                color: lock.theme.scrimStrong
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
                    text: Qt.formatDateTime(lock.clock.date, "h:mm AP")
                    color: lock.theme.textStrong
                    font.family: lock.runtime.fontMono
                    font.pixelSize: lock.theme.fontSize(Math.max(62, Math.min(104, parent.parent.width * 0.055)))
                    font.weight: Font.Light
                    font.letterSpacing: -2
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(lock.clock.date, "dddd, d MMMM").toUpperCase()
                    color: lock.theme.textMuted
                    font.family: lock.runtime.fontMono
                    font.pixelSize: lock.theme.fontSize(11)
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2
                }
            }

            ShellSurface {
                id: authCard

                width: lock.authRevealed ? Math.min(parent.width - 80, 430) : 68
                height: lock.authRevealed ? contentColumn.implicitHeight + lock.theme.spacing5 * 2 : 68
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: Math.max(70, parent.height * 0.11)
                }

                theme: lock.theme
                motion: lock.motion
                surfaceLayer: ShellSurface.Pane
                cornerRadius: lock.authRevealed ? lock.theme.radiusPanel : lock.theme.radiusLarge

                Behavior on width {
                    Anim {
                        motion: lock.motion
                        type: Anim.DefaultSpatial
                    }
                }
                Behavior on height {
                    Anim {
                        motion: lock.motion
                        type: Anim.DefaultSpatial
                    }
                }
                Behavior on cornerRadius {
                    Anim {
                        motion: lock.motion
                        type: Anim.DefaultSpatial
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: lock.theme.spacing2
                    opacity: lock.authRevealed ? 0 : 1

                    LockGlyph {
                        width: 20
                        height: 20
                    }

                    Behavior on opacity {
                        Anim {
                            motion: lock.motion
                            type: Anim.FastEffects
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: lock.theme.spacing5
                    opacity: lock.authRevealed ? 1 : 0

                    Behavior on opacity {
                        Anim {
                            motion: lock.motion
                            type: Anim.DefaultEffects
                        }
                    }

                    Column {
                        id: contentColumn

                        width: parent.width
                        spacing: lock.theme.spacing3

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: lock.theme.spacing1

                            LockGlyph {
                                width: 44
                                height: 44
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Quickshell.env("USER") || "user"
                                color: lock.theme.textStrong
                                font.family: lock.runtime.fontMono
                                font.pixelSize: lock.theme.fontSize(18)
                                font.weight: Font.DemiBold
                            }
                        }

                        ShellSurface {
                            width: parent.width
                            height: 54
                            theme: lock.theme
                            motion: lock.motion
                            surfaceLayer: ShellSurface.Group
                            cornerRadius: lock.theme.radiusMedium
                            outlined: passwordInput.activeFocus
                            borderColor: passwordInput.activeFocus ? lock.theme.accent : lock.theme.subtleBorder

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
                                font.pixelSize: lock.theme.fontSize(17)
                                clip: true

                                onTextEdited: {
                                    lock.password = text;
                                    lock.authRevealed = text.length > 0;
                                    if (text.length === 0) {
                                        lock.statusText = "";
                                        lock.statusError = false;
                                    }
                                }

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        if (!lock.authRevealed)
                                            lock.authRevealed = true;
                                        else
                                            lock.submitPassword();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
                                        lock.password = "";
                                        text = "";
                                        lock.authRevealed = false;
                                        lock.statusText = "";
                                        lock.statusError = false;
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
                            font.pixelSize: lock.theme.fontSize(9)
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    visible: !lock.authRevealed
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        lock.authRevealed = true;
                        passwordInput.forceActiveFocus();
                    }
                }
            }
        }
    }
}
