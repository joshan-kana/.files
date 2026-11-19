import QtQuick
import QtTest
import "../../modules/desktop/hyprland/shell/qml" as Desktop

TestCase {
    name: "ExpansionHistory"
    when: true

    Desktop.ShellExpansionState {
        id: expansion
    }

    function init(): void {
        expansion.close();
        expansion.finishClose();
    }

    function test_controlsDetailBack(): void {
        const screen = Qt.createQmlObject("import QtQml; QtObject {}", this, "screen");
        expansion.show("system", screen, 200, 48, 32, "controls");
        compare(expansion.currentName, "system");
        expansion.enterDetail("theme");
        compare(expansion.currentView, "theme");
        compare(expansion.backDestination, "controls");
        expansion.back();
        compare(expansion.currentView, "controls");
        expansion.close();
        expansion.finishClose();
        compare(expansion.currentName, "");
        compare(expansion.screen, null);
    }

    function test_mediaReturnsToControls(): void {
        const screen = Qt.createQmlObject("import QtQml; QtObject {}", this, "screen");
        expansion.show("system", screen, 100, 40, 32, "controls");
        expansion.show("media", screen, 180, 52, 40, "");
        compare(expansion.currentName, "media");
        compare(expansion.backDestination, "controls");
        compare(expansion.originCenter, 180);
        expansion.back();
        compare(expansion.currentName, "system");
        compare(expansion.currentView, "controls");
    }

    function test_weatherReturnsToCalendar(): void {
        const screen = Qt.createQmlObject("import QtQml; QtObject {}", this, "screen");
        expansion.show("calendar", screen, 100, 36, 28, "");
        expansion.show("weather", screen, 200, 48, 32, "");
        compare(expansion.backDestination, "calendar");
        expansion.back();
        compare(expansion.currentName, "calendar");
        compare(expansion.backDestination, "");
    }

    function test_repeatToggleCloses(): void {
        const screen = Qt.createQmlObject("import QtQml; QtObject {}", this, "screen");
        expansion.toggle("system", screen, 120, 48, 32, "");
        verify(expansion.hasCurrent);
        expansion.toggle("system", screen, 120, 48, 32, "");
        verify(!expansion.hasCurrent);
        expansion.finishClose();
        compare(expansion.currentName, "");
        compare(expansion.originWidth, 0);
    }

    function test_directNavigationClearsHistory(): void {
        const screen = Qt.createQmlObject("import QtQml; QtObject {}", this, "screen");
        expansion.show("system", screen, 120, 48, 32, "controls");
        expansion.enterDetail("theme");
        expansion.navigate("calendar");
        compare(expansion.currentName, "calendar");
        compare(expansion.currentView, "");
        compare(expansion.backDestination, "");
    }
}
