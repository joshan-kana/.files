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
    vec2 pixel = max(screenSize, vec2(1.0));
    float blockSize = 1.0 + floor(FX_INTENSITY * FX_SHAPE * 15.0);
    vec2 blockUv = floor(uv * pixel / blockSize) * blockSize / pixel;
    uv = mix(uv, blockUv, FX_INTENSITY * FX_TEXTURE * 0.6);
    float row = floor(gl_FragCoord.y / (5.0 + FX_SHAPE * 40.0));
    float trigger = step(0.94 - FX_INTENSITY * FX_ARTIFACTS * 0.35, hash(vec2(row, frame)));
    float jump = (hash(vec2(row + 10.0, frame)) - 0.5) * trigger
                 * FX_INTENSITY * FX_SHAPE * 0.13;
    uv.x = clamp(uv.x + jump, 0.0, 1.0);
    float separation = FX_INTENSITY * FX_COLOR * (2.0 + 26.0 * trigger) / pixel.x;
    vec3 src = vec3(
        texture(tex, clamp(uv + vec2(separation, 0), 0.0, 1.0)).r,
        texture(tex, uv).g,
        texture(tex, clamp(uv - vec2(separation, 0), 0.0, 1.0)).b
    );
    float strip = step(0.93, hash(vec2(row, floor(t * 9.0) + 31.0)));
    src *= 1.0 - FX_INTENSITY * FX_LINES * strip * 0.4;
    float colourFault = hash(vec2(floor(gl_FragCoord.x / 100.0), row + frame)) - 0.5;
    src += colourFault * trigger * FX_ARTIFACTS * FX_INTENSITY * 0.20;
    fragColor = vec4(clamp(src, 0.0, 1.0), texture(tex, uv).a);
}
