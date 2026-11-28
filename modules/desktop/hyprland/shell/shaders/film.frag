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
    float t = time * FX_SPEED;
    float frame = floor(t * 24.0);
    vec2 p = uv - 0.5;
    vec2 drift = vec2(
        sin(frame * 3.71),
        cos(frame * 2.13)
    ) * FX_INTENSITY * FX_SHAPE * 0.0018;
    vec4 scene = texture(tex, clamp(uv + drift, 0.0, 1.0));
    float lum = dot(scene.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 sepia = vec3(lum * 1.10, lum * 0.99, lum * 0.80);
    vec3 colour = mix(scene.rgb, sepia, FX_INTENSITY * FX_COLOR * 0.62);
    float grain = hash(floor(gl_FragCoord.xy * 0.73) + vec2(frame * 0.61, frame * 1.17)) - 0.5;
    colour += grain * FX_INTENSITY * FX_TEXTURE * 0.20;
    float flicker = 1.0 + (hash(vec2(frame, 32.0)) - 0.5)
                    * FX_INTENSITY * FX_ARTIFACTS * 0.09;
    float scratchColumn = hash(vec2(floor(gl_FragCoord.x * 0.20), floor(frame * 0.11)));
    float scratch = step(0.998 - FX_LINES * FX_INTENSITY * 0.02, scratchColumn);
    colour += scratch * FX_INTENSITY * FX_LINES * 0.16;
    float vignette = 1.0 - smoothstep(0.28, 0.82, length(p)) * FX_INTENSITY * 0.46;
    colour *= flicker * vignette;
    fragColor = vec4(clamp(colour, 0.0, 1.0), scene.a);
}
