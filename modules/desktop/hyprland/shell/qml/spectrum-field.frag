#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uTime;
    float uAspect;
    float uSub;
    float uBass;
    float uMid;
    float uHigh;
    float uPeak;
    vec4 uAccent;
    vec4 uPositive;
    vec4 uWarning;
};

float saturate(float value) {
    return clamp(value, 0.0, 1.0);
}

float ridge(float distanceToLine, float width) {
    return exp(-distanceToLine * distanceToLine / max(width, 0.0001));
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= max(uAspect, 0.001);

    float sub = pow(saturate(uSub), 0.72);
    float bass = pow(saturate(uBass), 0.78);
    float mids = saturate(uMid);
    float highs = saturate(uHigh);
    float transient = pow(saturate(uPeak), 1.35);

    // Low-end energy controls the broadest motion and therefore carries the
    // most visual mass. Higher bands decorate it instead of overpowering it.
    float lowMass = saturate(sub * 0.72 + bass * 0.58);
    float phase = uTime * (1.15 + transient * 1.35);

    float warp =
        sin(p.x * 2.25 - phase * 1.05) * (0.045 + lowMass * 0.18)
        + sin(p.x * 5.4 + phase * 1.55) * (0.018 + bass * 0.055)
        + sin(p.x * 12.0 - phase * 2.1) * highs * 0.018;

    float mainDistance = abs(p.y - warp);
    float mainWidth = 0.010 + lowMass * 0.055 + transient * 0.018;
    float mainGlow = ridge(mainDistance, mainWidth);

    float echoWarp =
        sin(p.x * 1.35 + phase * 0.68 + 1.8) * (0.07 + sub * 0.20)
        - 0.28;
    float echoGlow = ridge(abs(p.y - echoWarp), 0.025 + bass * 0.05) * 0.65;

    float radius = length(vec2(p.x * 0.58, p.y));
    float shockCenter = 0.30 + fract(phase * 0.13) * (0.82 + sub * 0.35);
    float shock = ridge(abs(radius - shockCenter), 0.0035 + transient * 0.016);
    shock *= transient * (0.25 + lowMass * 0.9);

    float subBody = exp(-abs(p.y) * (3.4 - sub * 1.7));
    subBody *= exp(-abs(p.x) * (0.72 - sub * 0.18));
    subBody *= lowMass * 0.30;

    float shimmer =
        0.5 + 0.5 * sin(
            p.x * (25.0 + highs * 18.0)
            + p.y * 16.0
            - phase * (3.0 + highs * 4.0)
        );
    shimmer = pow(shimmer, 8.0) * highs * (0.10 + mids * 0.12);

    float edgeFade = 1.0 - smoothstep(0.42, 1.16, abs(uv.y - 0.5) * 2.0);
    edgeFade *= 1.0 - smoothstep(0.25, uAspect + 0.15, abs(p.x));

    vec3 accent = uAccent.rgb;
    vec3 positive = uPositive.rgb;
    vec3 warning = uWarning.rgb;

    vec3 lowColor = mix(accent, warning, saturate(sub * 0.52));
    vec3 highColor = mix(accent, positive, saturate(highs * 0.78 + mids * 0.20));

    float field = mainGlow * (0.44 + lowMass * 0.56);
    field += echoGlow * lowMass;
    field += shock;
    field += subBody;
    field += shimmer;

    vec3 color = mix(lowColor, highColor, saturate(highs * 0.48 + uv.x * 0.36));
    color *= field * edgeFade;

    float ambient = (0.018 + lowMass * 0.035) * edgeFade;
    color += mix(accent, positive, uv.x) * ambient;

    float alpha = saturate(field * 0.72 + ambient * 4.0);
    fragColor = vec4(color * alpha, alpha) * qt_Opacity;
}
