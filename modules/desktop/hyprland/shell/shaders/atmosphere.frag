#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;
    float aspect;
    float intensity;
    vec4 toneA;
    vec4 toneB;
    vec4 toneC;
    vec4 audio; // sustained energy, transient pulse, treble
    int style;
} u;

const float tau = 6.28318530718;

float hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

float noise2(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 w = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), w.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), w.x), w.y);
}

float cloud(vec2 p) {
    return noise2(p) * 0.57 + noise2(p * 2.07 + 7.2) * 0.28
         + noise2(p * 4.17 - 5.1) * 0.15;
}

vec3 palette(float t) {
    return mix(mix(u.toneA.rgb, u.toneB.rgb, smoothstep(0.0, 0.5, t)),
               u.toneC.rgb, smoothstep(0.5, 1.0, t));
}

// Overlapping curved curtains with a narrow luminous crest and a broad,
// translucent bloom. Audio controls their height, not global flashing.
void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = (uv - 0.5) * vec2(u.aspect, 1.0);
    vec4 effect;
    effect = vec4(0);
    float vignette = 1.0 - smoothstep(0.45, 1.0, length((uv - 0.5) * 1.6)) * 0.32;
    float alpha = clamp(effect.a * u.intensity * vignette, 0.0, 1.0);
    fragColor = vec4(clamp(effect.rgb, 0.0, 1.0) * alpha, alpha) * u.qt_Opacity;
}
