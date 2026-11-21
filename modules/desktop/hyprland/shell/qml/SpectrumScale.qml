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

    // Invert the display warp when evenly spaced visual columns need to
    // sample the analyser's logarithmic (unwarped) frequency bands.
    function toNormalized(position: real): real {
        const target = Math.max(0, Math.min(1, position));
        let lower = 0;
        let upper = 1;
        for (let step = 0; step < 15; step++) {
            const middle = (lower + upper) / 2;
            if (fromNormalized(middle) < target)
                lower = middle;
            else
                upper = middle;
        }
        return (lower + upper) / 2;
    }

    function fromFrequency(frequency: real): real {
        const low = Math.max(1, lowHz);
        const high = Math.max(low + 1, highHz);
        const safe = Math.max(low, Math.min(high, frequency));
        const normalized = Math.log(safe / low) / Math.log(high / low);
        return fromNormalized(normalized);
    }
}
