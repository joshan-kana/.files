pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.UPower

QtObject {
    id: root

    property bool active: false
    readonly property var profiles: active ? (PowerProfiles.hasPerformanceProfile ? ["power-saver", "balanced", "performance"] : ["power-saver", "balanced"]) : []
    readonly property string current: !active ? "" : PowerProfiles.profile === PowerProfile.PowerSaver ? "power-saver" : PowerProfiles.profile === PowerProfile.Performance ? "performance" : "balanced"
    readonly property bool available: active
    // Direct D-Bus-backed properties update reactively; there is no polling or
    // child process whose exit could leave the tile stale.
    readonly property bool applying: false

    function setProfile(profile: string): void {
        if (!available || !profiles.includes(profile) || profile === current)
            return;
        if (profile === "power-saver")
            PowerProfiles.profile = PowerProfile.PowerSaver;
        else if (profile === "balanced")
            PowerProfiles.profile = PowerProfile.Balanced;
        else if (profile === "performance" && PowerProfiles.hasPerformanceProfile)
            PowerProfiles.profile = PowerProfile.Performance;
    }

    function cycle(): void {
        if (!available || profiles.length === 0)
            return;
        const position = Math.max(0, profiles.indexOf(current));
        setProfile(profiles[(position + 1) % profiles.length]);
    }

    function label(profile: string): string {
        if (profile === "power-saver")
            return "Power saver";
        if (profile === "balanced")
            return "Balanced";
        if (profile === "performance")
            return "Performance";
        return profile;
    }
}
