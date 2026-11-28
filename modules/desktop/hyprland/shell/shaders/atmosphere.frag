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
    vec4 toneD;
    vec4 toneE;
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
    float p = clamp(t, 0.0, 1.0) * 4.0;
    if (p < 1.0)
        return mix(u.toneA.rgb, u.toneB.rgb, p);
    if (p < 2.0)
        return mix(u.toneB.rgb, u.toneC.rgb, p - 1.0);
    if (p < 3.0)
        return mix(u.toneC.rgb, u.toneD.rgb, p - 2.0);
    return mix(u.toneD.rgb, u.toneE.rgb, p - 3.0);
}

// Overlapping curved curtains with a narrow luminous crest and a broad,
// translucent bloom. Audio controls their height, not global flashing.
vec4 aurora(vec2 uv, vec2 p) {
    vec3 light = vec3(0);
    float density = 0.0;
    for (int i = 0; i < 3; ++i) {
        float k = float(i);
        float x = p.x * 3.1 + k * 0.73;
        float crest = 0.33 + k * 0.15
            + (0.10 + u.audio.x * 0.045) * sin(x + u.phase + k)
            + 0.055 * sin(x * 2.13 - u.phase * 2.0 + k * 2.0)
            + u.audio.y * 0.032 * sin(x * 3.0 + k);
        float d = uv.y - crest;
        float curtain = exp(-abs(d) * (d > 0.0 ? 10.5 : 20.0));
        float edge = exp(-abs(d) * 75.0);
        float folds = 0.65 + 0.35 * sin(x * 4.0 + sin(x * 1.8 + u.phase) * 2.5);
        float weight = curtain * folds * (0.36 + 0.12 * u.audio.x)
                     + edge * (0.15 + u.audio.z * 0.12);
        light += palette(k * 0.5) * weight;
        density += weight;
    }
    return vec4(light / max(density, 0.001), min(density, 0.88));
}

vec4 liquid(vec2 p) {
    vec2 q = p * 3.8;
    q += vec2(sin(q.y * 1.5 + u.phase), cos(q.x * 1.4 - u.phase)) * 0.56;
    q += vec2(sin(q.y * 2.0 - u.phase * 2.0), cos(q.x * 1.7 + u.phase)) * 0.28;
    float v = 0.5 + 0.5 * sin(q.x + q.y * 0.85 + u.phase
        + u.audio.y * 0.35 * sin(length(p) * 9.0));
    float sheen = pow(1.0 - abs(2.0 * v - 1.0), 14.0);
    float broad = 0.16 + 0.45 * v;
    vec3 col = palette(v) * (0.70 + sheen * (0.38 + u.audio.z * 0.18));
    return vec4(col, broad + sheen * 0.18 + u.audio.x * 0.08);
}

vec4 nebula(vec2 p) {
    vec2 drift = vec2(cos(u.phase), sin(u.phase)) * 0.26;
    vec2 q = p * 3.7 + drift;
    float n = cloud(q);
    float m = cloud(q * 1.3 + vec2(n * 1.8, -n * 1.1));
    float gas = smoothstep(0.20, 0.82, m);
    vec2 grid = p * 118.0;
    vec2 cell = floor(grid);
    float seed = hash(cell);
    vec2 offset = vec2(hash(cell + 5.0), hash(cell - 11.0)) * 0.52 + 0.24;
    float star = (1.0 - smoothstep(0.025, 0.13, length(fract(grid) - offset)))
        * step(0.975, seed) * (0.7 + 0.3 * sin(u.phase * 3.0 + seed * 80.0));
    float alpha = gas * (0.65 + u.audio.x * 0.15);
    vec3 col = mix(palette(clamp(n + m * 0.3, 0.0, 1.0)),
                   mix(u.toneC.rgb, vec3(1.0), 0.55), star);
    return vec4(col, max(alpha, star * (0.6 + u.audio.z * 0.4)));
}

vec4 ripples(vec2 p) {
    vec3 light = vec3(0);
    float density = 0.0;
    for (int i = 0; i < 3; ++i) {
        float k = float(i);
        vec2 center = vec2(cos(k * tau / 3.0 + u.phase), sin(k * tau / 3.0 + u.phase)) * vec2(0.34, 0.18);
        float d = length(p - center);
        float wave = 0.5 + 0.5 * sin(d * 42.0 - u.phase * 5.0 + k * 1.7 - u.audio.y * 1.2);
        float crest = pow(wave, 14.0);
        float glow = pow(wave, 3.0);
        float w = (crest * 0.42 + glow * 0.16) * exp(-d * 1.7) * (1.0 + u.audio.x * 0.55);
        light += palette(k * 0.5) * w;
        density += w;
    }
    return vec4(light / max(density, 0.001), min(density, 0.82));
}

vec4 geometry(vec2 p) {
    vec2 q = p * 9.0;
    q += vec2(sin(q.y * 0.38 + u.phase), sin(q.x * 0.34 - u.phase)) * (0.3 + u.audio.x * 0.25);
    // Axial hexagonal tiling with a shared staggered lattice.
    vec2 lattice = vec2(1.0, 1.7320508);
    vec2 a = mod(q, lattice) - lattice * 0.5;
    vec2 b = mod(q + lattice * 0.5, lattice) - lattice * 0.5;
    vec2 local = dot(a, a) < dot(b, b) ? a : b;
    vec2 cell = q - local;
    float d = max(abs(local.x), dot(abs(local), vec2(0.5, 0.8660254)));
    float edge = smoothstep(0.445, 0.485, d);
    float seed = hash(floor(cell * 2.0 + 0.01));
    float breath = 0.5 + 0.5 * sin(u.phase * 2.0 + seed * tau);
    float inset = 1.0 - smoothstep(0.20 + u.audio.y * 0.075, 0.24 + u.audio.y * 0.075, d);
    return vec4(palette(seed), edge * (0.24 + u.audio.z * 0.22) + inset * (0.12 + breath * 0.20));
}

vec4 flow(vec2 p) {
    vec2 q = p * 7.0;
    q.y += sin(q.x * 0.7 + u.phase) * (0.6 + u.audio.x * 0.35);
    q.y += sin(q.x * 1.25 - u.phase * 2.0) * 0.22;
    float lane = floor(q.y * 2.0);
    float seed = hash(vec2(lane, 1.0));
    float local = abs(fract(q.y * 2.0) - 0.5);
    float line = 1.0 - smoothstep(0.025, 0.09, local);
    float dash = pow(0.5 + 0.5 * sin(q.x * 3.5 - u.phase * 4.0 + seed * tau), 8.0);
    float glow = (1.0 - smoothstep(0.04, 0.40, local)) * 0.09;
    return vec4(palette(seed), glow + line * (0.13 + dash * (0.56 + u.audio.z * 0.22)));
}

vec4 prism(vec2 p) {
    vec2 q = p * 3.3;
    float slope = 0.52 + 0.12 * sin(u.phase);
    float x = q.x + q.y * slope;
    float y = q.y - q.x * 0.26;
    float fold = abs(fract(x + 0.12 * sin(y * 1.7 + u.phase)) - 0.5);
    float plane = floor(x);
    float hue = fract(plane * 0.236 + 0.12 * sin(u.phase));
    float edge = exp(-fold * 48.0);
    float reflection = pow(0.5 + 0.5 * cos(y * 2.5 + u.phase + hue * tau), 10.0);
    vec3 col = mix(palette(hue), vec3(1), edge * (0.18 + u.audio.z * 0.18));
    return vec4(col, 0.12 + edge * (0.52 + u.audio.y * 0.14) + reflection * 0.22);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = (uv - 0.5) * vec2(u.aspect, 1.0);
    vec4 effect;
    if (u.style == 0) effect = aurora(uv, p);
    else if (u.style == 1) effect = liquid(p);
    else if (u.style == 2) effect = nebula(p);
    else if (u.style == 3) effect = ripples(p);
    else if (u.style == 4) effect = geometry(p);
    else if (u.style == 5) effect = flow(p);
    else if (u.style == 6) effect = prism(p);
    else effect = vec4(0);
    float vignette = 1.0 - smoothstep(0.45, 1.0, length((uv - 0.5) * 1.6)) * 0.32;
    float alpha = clamp(effect.a * u.intensity * vignette, 0.0, 1.0);
    fragColor = vec4(clamp(effect.rgb, 0.0, 1.0) * alpha, alpha) * u.qt_Opacity;
}
