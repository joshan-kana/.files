import QtQuick
import "SceneProfiles.js" as Profiles

QtObject {
    id: scenes
    required property AppearancePreferences appearance
    required property Motion motion
    required property NotificationState notifications

    property PreferenceStore preferences: PreferenceStore {
        category: "Scenes"
        defaults: ({
                library: {
                    items: []
                }
            })
    }
    readonly property var profiles: Profiles.cleanProfiles(preferences.value("library").items)
    property string activeName: ""
    readonly property bool active: activeName.length > 0

    function snapshot(name: string): var {
        const values = {};
        for (const key of Profiles.appearanceKeys)
            values[key] = appearance.effective(key);
        return {
            name: name.trim(),
            appearance: values,
            animations: motion.enabled,
            silent: notifications.manualSilent,
            presentation: notifications.presentation
        };
    }

    function save(name: string): bool {
        const profile = snapshot(name);
        if (!Profiles.validProfile(profile) || profiles.length >= 12 || profiles.some(entry => entry.name === profile.name))
            return false;
        preferences.set("library", {
            items: [...profiles, profile]
        });
        return true;
    }

    function apply(index: int): void {
        const profile = profiles[index];
        if (!Profiles.validProfile(profile))
            return;
        activeName = profile.name;
        appearance.setSceneValues(Profiles.appearanceValues(profile));
        motion.setSceneEnabled(profile.animations);
        notifications.sceneDelivery = {
            silent: profile.silent,
            presentation: profile.presentation
        };
    }

    function stop(): void {
        activeName = "";
        appearance.setSceneValues({});
        motion.setSceneEnabled(null);
        notifications.sceneDelivery = null;
    }

    function remove(index: int): void {
        const profile = profiles[index];
        if (!profile || profile.name === activeName)
            return;
        preferences.set("library", {
            items: profiles.filter(entry => entry.name !== profile.name)
        });
    }
}
