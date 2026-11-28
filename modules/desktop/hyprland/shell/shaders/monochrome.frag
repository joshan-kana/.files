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
    // Deliberately no time sample, so the compositor can retain damage-based
    // redraw and VFR while this static effect is selected.
    vec4 src = texture(tex, v_texcoord);
    float lum = dot(src.rgb, vec3(0.2126, 0.7152, 0.0722));
    float contrast = 1.0 + FX_SHAPE * 1.25;
    float bw = clamp((lum - 0.5) * contrast + 0.5, 0.0, 1.0);
    float dither = (hash(floor(gl_FragCoord.xy)) - 0.5) * FX_TEXTURE * 0.12;
    bw = clamp(bw + dither, 0.0, 1.0);
    vec3 ink = mix(vec3(bw), vec3(bw * 0.58, bw * 0.88, bw * 0.69), FX_COLOR);
    float scan = 0.5 + 0.5 * cos(gl_FragCoord.y * 3.1415926535);
    ink *= 1.0 - FX_LINES * 0.20 * scan;
    float vignette = 1.0 - smoothstep(0.35, 0.83, length(v_texcoord - 0.5)) * FX_ARTIFACTS * 0.45;
    ink *= vignette;
    fragColor = vec4(mix(src.rgb, ink, FX_INTENSITY), src.a);
}
