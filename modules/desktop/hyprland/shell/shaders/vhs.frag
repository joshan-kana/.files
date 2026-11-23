#version 300 es
precision highp float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D tex;
uniform vec2 screenSize;
uniform float time;

// Replaced by the runtime controller. Intensity is deliberately non-linear:
// low settings retain readability; the high end can destroy the signal.
const float VHS_INTENSITY = 0.45;
const float VHS_TRACKING = 1.00;
const float VHS_CHROMA = 1.00;
const float VHS_NOISE = 1.00;
const float VHS_SCANLINES = 1.00;
const float VHS_SPEED = 1.00;

float tapeHash(vec2 cell) {
    vec3 p = fract(vec3(cell.xyx) * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

void main() {
    float strength = clamp(VHS_INTENSITY, 0.0, 1.0);
    float severe = strength * strength;
    vec2 pixel = gl_FragCoord.xy;
    float tapeTime = time * VHS_SPEED;
    float frame = floor(tapeTime * 24.0);

    // Moving tracking instability and a rolling horizontal tear. At the high
    // end, the tear may displace image rows by over a hundred physical pixels.
    float trackingRow = floor(pixel.y / 6.0);
    float jitter = tapeHash(vec2(trackingRow, floor(tapeTime * 14.0))) - 0.5;
    float tearCenter = mod(tapeTime * (175.0 + severe * 350.0), screenSize.y + 260.0) - 130.0;
    float tearBand = 1.0 - smoothstep(12.0, 80.0, abs(pixel.y - tearCenter));
    float tearDirection = tapeHash(vec2(floor(tapeTime * 8.0), 19.0)) * 2.0 - 1.0;
    float displacement = (jitter * (3.0 + 37.0 * severe) + tearBand * tearDirection * (8.0 + 145.0 * severe)) * strength * VHS_TRACKING;

    vec2 uv = clamp(v_texcoord + vec2(displacement / max(1.0, screenSize.x), 0.0), 0.0, 1.0);
    float chroma = (0.5 + 18.0 * severe + tearBand * severe * 18.0) * strength * VHS_CHROMA / max(1.0, screenSize.x);
    vec4 center = texture(tex, uv);
    vec3 colour = vec3(
        texture(tex, clamp(uv + vec2(chroma, 0.0), 0.0, 1.0)).r,
        center.g,
        texture(tex, clamp(uv - vec2(chroma, 0.0), 0.0, 1.0)).b
    );

    // Moving grain, uneven tape dropout, alternating scanlines and the thick
    // bright/dark tracking bar become much harsher near maximum intensity.
    float grain = (tapeHash(floor(pixel / vec2(2.0, 3.0)) + vec2(frame * 0.77, frame * 1.13)) - 0.5);
    float dropout = step(0.995 - 0.14 * severe, tapeHash(vec2(floor(pixel.y / 4.0), frame)));
    float scanline = mod(floor(pixel.y), 2.0);
    float flicker = 1.0 - 0.10 * severe * VHS_NOISE * (0.5 + 0.5 * sin(tapeTime * 17.0));
    float trackingFlash = tearBand * (0.18 + 0.32 * severe) * tearDirection * VHS_TRACKING;

    colour *= flicker * (1.0 - strength * VHS_SCANLINES * (0.06 + 0.45 * severe) * scanline);
    colour *= 1.0 - dropout * strength * VHS_NOISE * (0.08 + 0.70 * severe);
    colour += vec3((grain * (0.08 + 0.62 * severe) * VHS_NOISE + trackingFlash) * strength);

    fragColor = vec4(clamp(colour, 0.0, 1.0), center.a);
}
