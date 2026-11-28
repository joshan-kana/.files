import QtQuick

QtObject {
    id: guard

    property string pending: ""
    property int timeoutMs: 5000
    signal expired

    property Timer expiry: Timer {
        interval: guard.timeoutMs
        repeat: false
        onTriggered: {
            guard.cancel();
            guard.expired();
        }
    }

    function request(action: string): bool {
        if (!action)
            return false;
        if (pending === action) {
            cancel();
            return true;
        }
        pending = action;
        expiry.restart();
        return false;
    }

    function cancel(): void {
        expiry.stop();
        pending = "";
    }
}
