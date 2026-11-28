#version 300 es
precision highp float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;
uniform vec2 screenSize;
uniform float time;

// Values are validated from the Nix-declared effect ranges at the compositor
// controller boundary. Every visual family has its own persisted parameters.
const float FX_INTENSITY = 0.60;
const float FX_SHAPE = 0.50;
const float FX_COLOR = 0.50;
const float FX_TEXTURE = 0.50;
const float FX_LINES = 0.50;
const float FX_SPEED = 1.00;
const float FX_ARTIFACTS = 0.20;

float hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

void main() {
    vec2 uv = v_texcoord;
    vec2 p = uv * 2.0 - 1.0;
    float r2 = dot(p, p);
    vec2 warped = 0.5 + p * (0.5 + FX_INTENSITY * FX_SHAPE * r2 * 0.055);
    vec2 safeUv = clamp(warped, vec2(0.0), vec2(1.0));
    vec3 src = texture(tex, safeUv).rgb;
    vec2 dx = vec2(1.0 / max(screenSize.x, 1.0), 0.0);
    float halo = FX_INTENSITY * FX_TEXTURE * 0.22;
    vec3 blur = (texture(tex, clamp(safeUv + dx * 2.0, 0.0, 1.0)).rgb
               + texture(tex, clamp(safeUv - dx * 2.0, 0.0, 1.0)).rgb) * 0.5;
    src = mix(src, max(src, blur), halo);
    float mask = mod(floor(gl_FragCoord.x), 3.0);
    vec3 phosphors = mask < 1.0 ? vec3(1.0, 0.72, 0.72)
                  : mask < 2.0 ? vec3(0.75, 1.0, 0.75)
                  : vec3(0.74, 0.74, 1.0);
    float shadowMask = FX_INTENSITY * FX_COLOR * 0.25;
    src *= mix(vec3(1.0), phosphors, shadowMask);
    float scanline = 0.5 + 0.5 * cos(gl_FragCoord.y * 3.1415926535);
    src *= 1.0 - FX_INTENSITY * FX_LINES * scanline * 0.30;
    float rim = 1.0 - smoothstep(0.66, 1.41, length(p));
    float flicker = 1.0 - FX_INTENSITY * FX_ARTIFACTS * 0.045 *
                    (0.5 + 0.5 * sin(time * FX_SPEED * 48.0));
    float outside = smoothstep(0.01, 0.04,
        min(min(warped.x, warped.y), min(1.0 - warped.x, 1.0 - warped.y)));
    src *= mix(1.0, 0.78 + 0.22 * rim, FX_INTENSITY) * flicker * outside;
    fragColor = vec4(clamp(src, 0.0, 1.0), texture(tex, safeUv).a);
}
