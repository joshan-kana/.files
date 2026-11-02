import QtQuick

QtObject {
    function progress(value: real, exponent: real): real {
        if (value <= 0)
            return 0;
        if (value >= 1)
            return 1;
        const power = exponent / 2;
        const first = Math.pow(value, power);
        return first / (first + Math.pow(1 - value, power));
    }

    function cornerPoint(cx: real, cy: real, radius: real, angle: real, exponent: real): var {
        const cosine = Math.cos(angle);
        const sine = Math.sin(angle);
        return {
            x: cx + radius * Math.sign(cosine) * Math.pow(Math.abs(cosine), 2 / exponent),
            y: cy + radius * Math.sign(sine) * Math.pow(Math.abs(sine), 2 / exponent)
        };
    }
}
