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
    float line = floor(gl_FragCoord.y * 0.45);
    float jitter = (hash(vec2(line, floor(t * 12.0))) - 0.5);
    float shift = jitter * FX_INTENSITY * FX_SHAPE * 0.009;
    float rolling = 0.5 + 0.5 * sin(gl_FragCoord.y * 0.024 - t * 5.0);
    uv.x = clamp(uv.x + shift * rolling, 0.0, 1.0);
    vec2 pixel = 1.0 / max(screenSize, vec2(1.0));
    float chroma = FX_INTENSITY * FX_COLOR * 3.0 * pixel.x;
    vec3 src = vec3(
        texture(tex, clamp(uv + vec2(chroma, 0), 0.0, 1.0)).r,
        texture(tex, uv).g,
        texture(tex, clamp(uv - vec2(chroma, 0), 0.0, 1.0)).b
    );
    float luminance = dot(src, vec3(0.2126, 0.7152, 0.0722));
    float edge = length(texture(tex, clamp(uv + pixel * 1.6, 0.0, 1.0)).rgb
                      - texture(tex, clamp(uv - pixel * 1.6, 0.0, 1.0)).rgb);
    vec3 cyan = vec3(0.22, 0.92, 1.00);
    vec3 hologram = mix(vec3(luminance), cyan * (0.4 + luminance), 0.55 + FX_COLOR * 0.45);
    float beams = pow(0.5 + 0.5 * sin(gl_FragCoord.y * 0.07 + t * 1.7), 10.0);
    float scan = 0.5 + 0.5 * sin(gl_FragCoord.y * 1.2 - t * 8.0);
    hologram += cyan * (edge * 0.16 + beams * FX_ARTIFACTS * 0.16);
    hologram *= 1.0 - FX_LINES * scan * 0.21;
    hologram += (hash(floor(gl_FragCoord.xy / 3.0) + floor(t * 15.0)) - 0.5)
                * FX_TEXTURE * 0.075;
    src = mix(src, hologram, FX_INTENSITY);
    fragColor = vec4(clamp(src, 0.0, 1.0), texture(tex, uv).a);
}
