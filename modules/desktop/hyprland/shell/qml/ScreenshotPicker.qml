pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: picker
    required property RuntimeConfig runtime
    required property Theme theme
    required property Motion motion
    property var captureScreen: null
    property bool open: false
    property bool pending: false
    property bool exporting: false
    property bool copying: true
    property string selectionMode: "image"
    property string audioMode: "none"
    readonly property string audioLabel: audioMode === "system" ? "SYSTEM AUDIO" : audioMode === "microphone" ? "MICROPHONE" : "NO AUDIO"
    property string snapshotPath: ""
    property string statusText: ""
    property real startX: 0
    property real startY: 0
    property real endX: 0
    property real endY: 0
    property bool dragging: false
    property bool initialiseSelection: true
    readonly property real leftEdge: Math.min(startX, endX)
    readonly property real topEdge: Math.min(startY, endY)
    readonly property real selectionWidth: Math.abs(endX - startX)
    readonly property real selectionHeight: Math.abs(endY - startY)
    signal snapshotReady

    screen: captureScreen
    visible: open
    focusable: open
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }
    WlrLayershell.namespace: "linux-desktop-frozen-screenshot"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function clamp(value: real, minimum: real, maximum: real): real {
        return Math.max(minimum, Math.min(maximum, value));
    }

    function begin(copy: bool, target: var, mode: string): void {
        if (open || pending || exporting || !target || runtime.frozenCapture.length === 0)
            return;
        captureScreen = target;
        copying = copy;
        selectionMode = mode;
        if (mode !== "record")
            audioMode = "none";
        pending = true;
        initialiseSelection = true;
        statusText = "";
        snapshotProcess.exec([runtime.frozenCapture, "snapshot", target.name]);
    }

    function initialiseRect(): void {
        if (!open || !initialiseSelection || width <= 0 || height <= 0)
            return;
        // Recalculate when Wayland replaces its provisional 500px geometry.
        // Freeze the user's rectangle only after their first interaction.
        startX = width * 0.25;
        startY = height * 0.25;
        endX = width * 0.75;
        endY = height * 0.75;
    }

    onWidthChanged: initialiseRect()
    onHeightChanged: initialiseRect()

    function showSnapshot(): void {
        if (!pending || frozen.status !== Image.Ready)
            return;
        pending = false;
        snapshotReady();
        open = true;
        Qt.callLater(() => {
            initialiseRect();
            if (open)
                keyboard.forceActiveFocus();
        });
    }

    function dismiss(clearFile: bool): void {
        if (exporting)
            return;
        const oldPath = snapshotPath;
        open = false;
        pending = false;
        dragging = false;
        snapshotPath = "";
        statusText = "";
        if (clearFile && oldPath.length > 0)
            Quickshell.execDetached([runtime.frozenCapture, "clear", oldPath]);
    }

    function capture(): void {
        if (!open || exporting || selectionWidth < 5 || selectionHeight < 5)
            return;
        const scaleX = frozen.implicitWidth / Math.max(1, width);
        const scaleY = frozen.implicitHeight / Math.max(1, height);
        const x = Math.floor(leftEdge * scaleX);
        const y = Math.floor(topEdge * scaleY);
        const fullWidth = Math.max(1, frozen.implicitWidth);
        const fullHeight = Math.max(1, frozen.implicitHeight);
        const w = Math.max(1, Math.min(fullWidth - x, Math.ceil(selectionWidth * scaleX)));
        const h = Math.max(1, Math.min(fullHeight - y, Math.ceil(selectionHeight * scaleY)));
        if (selectionMode === "record") {
            // The image is a selection backdrop only. The recorder captures
            // the live output, never the frozen image.
            const recordGeometry = String(Math.round(leftEdge + (captureScreen.x || 0))) + "," + String(Math.round(topEdge + (captureScreen.y || 0))) + " " + String(Math.ceil(selectionWidth)) + "x" + String(Math.ceil(selectionHeight));
            const outputName = captureScreen.name;
            const selectedAudio = audioMode;
            dismiss(true);
            Quickshell.execDetached([runtime.recordingToggle, "start", outputName, recordGeometry, selectedAudio]);
            return;
        }
        exporting = true;
        statusText = copying ? "COPYING EXACT FRAME…" : "SAVING EXACT FRAME…";
        exportProcess.exec([runtime.frozenCapture, copying ? "copy" : "save", snapshotPath, String(x), String(y), String(w), String(h)]);
    }

    function moveSelection(dx: real, dy: real, resize: bool): void {
        initialiseSelection = false;
        if (resize) {
            endX = clamp(endX + dx, 0, width);
            endY = clamp(endY + dy, 0, height);
            return;
        }
        const rectWidth = selectionWidth;
        const rectHeight = selectionHeight;
        const newX = clamp(leftEdge + dx, 0, Math.max(0, width - rectWidth));
        const newY = clamp(topEdge + dy, 0, Math.max(0, height - rectHeight));
        startX = newX;
        startY = newY;
        endX = newX + rectWidth;
        endY = newY + rectHeight;
    }

    function nextMonitor(): void {
        if (!open || exporting || Quickshell.screens.length < 2)
            return;
        const index = Quickshell.screens.indexOf(captureScreen);
        const next = Quickshell.screens[(index + 1) % Quickshell.screens.length];
        const wasCopying = copying;
        const mode = selectionMode;
        dismiss(true);
        begin(wasCopying, next, mode);
    }

    StdioCollector {
        id: snapshotOutput
    }
    Process {
        id: snapshotProcess
        stdout: snapshotOutput
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                picker.pending = false;
                console.warn("Frozen screenshot failed with exit code", exitCode);
                return;
            }
            picker.snapshotPath = snapshotOutput.text.trim();
        }
    }

    Process {
        id: exportProcess
        onExited: (exitCode, exitStatus) => {
            picker.exporting = false;
            if (exitCode === 0)
                picker.dismiss(false);
            else
                picker.statusText = "CAPTURE FAILED · ENTER TO RETRY · ESC CANCEL";
        }
    }

    Image {
        id: frozen
        anchors.fill: parent
        source: picker.snapshotPath.length > 0 ? "file://" + picker.snapshotPath : ""
        fillMode: Image.Stretch
        asynchronous: true
        cache: false
        smooth: false
        onStatusChanged: picker.showSnapshot()
    }

    // Four lightweight rects, rather than an opaque fullscreen shader, keep
    // the selected source pixels unmodified and show what will be exported.
    Item {
        anchors.fill: parent
        visible: picker.open
        z: 1
        readonly property color scrim: "#10161d"
        readonly property real dim: 0.48

        Rectangle {
            x: 0
            y: 0
            width: parent.width
            height: Math.max(0, picker.topEdge)
            color: parent.scrim
            opacity: parent.dim
        }
        Rectangle {
            x: 0
            y: picker.topEdge
            width: Math.max(0, picker.leftEdge)
            height: picker.selectionHeight
            color: parent.scrim
            opacity: parent.dim
        }
        Rectangle {
            x: picker.leftEdge + picker.selectionWidth
            y: picker.topEdge
            width: Math.max(0, picker.width - x)
            height: picker.selectionHeight
            color: parent.scrim
            opacity: parent.dim
        }
        Rectangle {
            x: 0
            y: picker.topEdge + picker.selectionHeight
            width: parent.width
            height: Math.max(0, picker.height - y)
            color: parent.scrim
            opacity: parent.dim
        }
    }

    Rectangle {
        id: selectedArea
        x: picker.leftEdge
        y: picker.topEdge
        width: picker.selectionWidth
        height: picker.selectionHeight
        radius: 5
        color: Qt.rgba(picker.theme.accent.r, picker.theme.accent.g, picker.theme.accent.b, 0.035)
        border.color: picker.theme.accent
        border.width: 2
        z: 2
        visible: picker.open
    }

    MouseArea {
        anchors.fill: parent
        z: 3
        cursorShape: Qt.CrossCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                picker.dismiss(true);
                return;
            }
            if (picker.exporting)
                return;
            picker.dragging = true;
            picker.initialiseSelection = false;
            picker.startX = mouse.x;
            picker.startY = mouse.y;
            picker.endX = mouse.x;
            picker.endY = mouse.y;
        }
        onPositionChanged: mouse => {
            if (picker.dragging) {
                picker.endX = picker.clamp(mouse.x, 0, picker.width);
                picker.endY = picker.clamp(mouse.y, 0, picker.height);
            }
        }
        onReleased: mouse => {
            if (!picker.dragging)
                return;
            picker.dragging = false;
            picker.endX = picker.clamp(mouse.x, 0, picker.width);
            picker.endY = picker.clamp(mouse.y, 0, picker.height);
            picker.capture();
        }
    }

    ShellSurface {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: picker.theme.spacing5
        }
        width: Math.min(picker.width - 48, 760)
        height: 65
        z: 5
        theme: picker.theme
        motion: picker.motion
        surfaceLayer: ShellSurface.Pane
        cornerRadius: picker.theme.radiusLarge
        Column {
            anchors.centerIn: parent
            spacing: picker.theme.spacing2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (picker.selectionMode === "record" ? "VIDEO REGION · " + picker.audioLabel : "FROZEN REGION · " + (picker.copying ? "COPY" : "SAVE")) + " · " + (picker.captureScreen ? picker.captureScreen.name : "")
                color: picker.theme.accent
                font.family: picker.runtime.fontMono
                font.pixelSize: picker.theme.fontSize(12)
                font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: picker.statusText.length > 0 ? picker.statusText : "DRAG SELECT · ARROWS MOVE · SHIFT+ARROWS RESIZE · F FULL · TAB DISPLAY · " + (picker.selectionMode === "record" ? "A AUDIO · " : "") + "ENTER CONFIRM · ESC CANCEL"
                color: picker.theme.textMuted
                font.family: picker.runtime.fontMono
                font.pixelSize: picker.theme.fontSize(9)
            }
        }
    }

    Text {
        z: 5
        x: picker.leftEdge + picker.selectionWidth / 2 - implicitWidth / 2
        y: picker.topEdge + picker.selectionHeight + picker.theme.spacing2
        text: Math.round(picker.selectionWidth) + " × " + Math.round(picker.selectionHeight)
        color: picker.theme.textStrong
        font.family: picker.runtime.fontMono
        font.pixelSize: picker.theme.fontSize(11)
        visible: picker.open
    }

    FocusScope {
        id: keyboard
        anchors.fill: parent
        z: 4
        focus: picker.open
        Keys.onPressed: event => {
            if (!picker.open || picker.exporting)
                return;
            const resize = !!(event.modifiers & Qt.ShiftModifier);
            const step = resize ? 8 : 16;
            if (event.key === Qt.Key_Escape) {
                picker.dismiss(true);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                picker.capture();
            } else if (event.key === Qt.Key_Tab) {
                picker.nextMonitor();
            } else if (event.key === Qt.Key_A && picker.selectionMode === "record") {
                picker.audioMode = picker.audioMode === "none" ? "system" : picker.audioMode === "system" ? "microphone" : "none";
            } else if (event.key === Qt.Key_F) {
                picker.initialiseSelection = false;
                picker.startX = 0;
                picker.startY = 0;
                picker.endX = picker.width;
                picker.endY = picker.height;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                picker.moveSelection(-step, 0, resize);
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                picker.moveSelection(step, 0, resize);
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                picker.moveSelection(0, -step, resize);
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                picker.moveSelection(0, step, resize);
            } else {
                return;
            }
            event.accepted = true;
        }
    }
}
