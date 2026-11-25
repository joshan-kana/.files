import QtQuick
import QtTest
import "../../modules/desktop/hyprland/shell/qml/SceneProfiles.js" as Profiles

TestCase {
    name: "SceneProfiles"

    function test_appearanceValues() {
        const appearance = {};
        for (const key of Profiles.appearanceKeys)
            appearance[key] = false;
        appearance.wallpaperSpectrumEnabled = true;
        const profile = {
            name: "Focus",
            appearance: appearance,
            animations: false,
            silent: true,
            presentation: false
        };
        verify(Profiles.validProfile(profile));
        const values = Profiles.appearanceValues(profile);
        compare(values.wallpaperSpectrumEnabled, true);
        compare(values.musicReactiveEnabled, false);
        compare(Profiles.cleanProfiles([profile, profile]).length, 1);
    }
}
