import QtQuick

QtObject {
    id: root

    property real lowHz: 20
    property real highHz: 20000

    // A single gentle display warp gives low-mid frequencies a little more
    // breathing room without special-casing any label or band.
    property real pivot: 0.52
    property real curvature: 1.2

    function fromNormalized(value: real): real {
        const t = Math.max(0, Math.min(1, value));
        const warped = t + curvature * t * (1 - t) * (pivot - t);
        return Math.max(0, Math.min(1, warped));
    }

    function fromFrequency(frequency: real): real {
        const low = Math.max(1, lowHz);
        const high = Math.max(low + 1, highHz);
        const safe = Math.max(low, Math.min(high, frequency));
        const normalized = Math.log(safe / low) / Math.log(high / low);
        return fromNormalized(normalized);
    }
}
