pragma ComponentBehavior: Bound
import QtQuick
import QtCore
import Quickshell
import Quickshell.Services.UPower

QtObject {
    id: root

    required property RuntimeConfig runtime
    property bool active: false
    property bool initialized: false
    property Settings preferences: Settings {
        id: saved
        location: "file://" + (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/desktop-shell/preferences.ini"
        category: "Power"
        property string policyOverridesJson: "{}"
    }
    readonly property var overrides: {
        try {
            const value = JSON.parse(saved.policyOverridesJson);
            return value && typeof value === "object" && !Array.isArray(value) ? value : {};
        } catch (_) {
            return {};
        }
    }
    readonly property bool automatic: typeof overrides.automatic === "boolean" ? overrides.automatic : runtime.powerPolicy.automatic
    readonly property string acProfile: ["power-saver", "balanced", "performance"].includes(overrides.acProfile) ? overrides.acProfile : runtime.powerPolicy.acProfile
    readonly property string batteryProfile: ["power-saver", "balanced", "performance"].includes(overrides.batteryProfile) ? overrides.batteryProfile : runtime.powerPolicy.batteryProfile
    readonly property bool onBattery: UPower.onBattery
    readonly property UPowerDevice battery: UPower.displayDevice
    readonly property bool batteryAvailable: battery !== null && battery.ready && battery.isLaptopBattery && battery.isPresent
    readonly property var physicalBatteries: UPower.devices ? UPower.devices.values.filter(device => device.ready && device.isLaptopBattery && device.isPresent) : []
    readonly property var holds: active ? PowerProfiles.holds : []
    readonly property bool performanceDegraded: PowerProfiles.degradationReason !== PerformanceDegradationReason.None
    readonly property string degradation: PerformanceDegradationReason.toString(PowerProfiles.degradationReason)
    readonly property string preferredProfile: onBattery ? batteryProfile : acProfile
    readonly property string resolvedProfile: profiles.includes(preferredProfile) ? preferredProfile : profiles.includes("balanced") ? "balanced" : profiles[0] || ""
    readonly property string policyStatus: !automatic ? "Manual selection" : holds.length > 0 ? "Automatic · waiting for application hold" : (onBattery ? "Battery" : "External power") + " · " + label(resolvedProfile) + (preferredProfile !== resolvedProfile ? " (fallback)" : "")
    onOnBatteryChanged: reconcilePolicy()
    onResolvedProfileChanged: reconcilePolicy()
    onAutomaticChanged: reconcilePolicy()
    onHoldsChanged: reconcilePolicy()
    Component.onCompleted: {
        initialized = true;
        reconcilePolicy();
    }

    function writePolicy(key: string, value: var): void {
        const next = Object.assign({}, overrides);
        next[key] = value;
        saved.policyOverridesJson = JSON.stringify(next);
        saved.setValue("policyOverridesJson", saved.policyOverridesJson);
    }

    function toggleAutomatic(): void {
        writePolicy("automatic", !automatic);
    }

    function setPolicyProfile(source: string, profile: string): void {
        if ((source !== "acProfile" && source !== "batteryProfile") || !profiles.includes(profile))
            return;
        writePolicy(source, profile);
    }

    function resetPolicy(): void {
        saved.policyOverridesJson = "{}";
        saved.setValue("policyOverridesJson", saved.policyOverridesJson);
    }

    function reconcilePolicy(): void {
        if (initialized && available && automatic && holds.length === 0 && resolvedProfile !== "")
            applyProfile(resolvedProfile);
    }

    function duration(seconds: real): string {
        if (!Number.isFinite(seconds) || seconds <= 0)
            return "Unknown";
        const minutes = Math.round(seconds / 60);
        return Math.floor(minutes / 60) + "h " + minutes % 60 + "m";
    }

    readonly property var profiles: active ? (PowerProfiles.hasPerformanceProfile ? ["power-saver", "balanced", "performance"] : ["power-saver", "balanced"]) : []
    readonly property string current: !active ? "" : PowerProfiles.profile === PowerProfile.PowerSaver ? "power-saver" : PowerProfiles.profile === PowerProfile.Performance ? "performance" : "balanced"
    readonly property bool available: active
    // Direct D-Bus-backed properties update reactively; there is no polling or
    // child process whose exit could leave the tile stale.
    readonly property bool applying: false

    function setProfile(profile: string): void {
        if (!available || !profiles.includes(profile))
            return;
        if (automatic)
            writePolicy("automatic", false);
        applyProfile(profile);
    }

    function applyProfile(profile: string): void {
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
