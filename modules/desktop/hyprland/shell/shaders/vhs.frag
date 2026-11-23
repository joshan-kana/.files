#version 300 es
precision highp float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;
uniform vec2 screenSize;
const float VHS_INTENSITY = 0.45;
float tapeNoise(vec2 point) {
    return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
}
void main() {
    vec4 source = texture(tex, v_texcoord);
    float widthPx = max(1.0, screenSize.x);
    float row = floor(gl_FragCoord.y / 3.0);
    float tracking = tapeNoise(vec2(row, 13.0));
    vec2 uv = clamp(v_texcoord + vec2((tracking - 0.5) * 2.4 / widthPx, 0.0), 0.0, 1.0);
    float chromaOffset = 1.4 / widthPx;
    vec3 signal = vec3(
        texture(tex, clamp(uv + vec2(chromaOffset, 0.0), 0.0, 1.0)).r,
        texture(tex, uv).g,
        texture(tex, clamp(uv - vec2(chromaOffset, 0.0), 0.0, 1.0)).b
    );
    float scanline = 0.96 + 0.04 * cos(gl_FragCoord.y * 3.14159265);
    float grain = (tapeNoise(floor(gl_FragCoord.xy / vec2(2.0, 3.0))) - 0.5) * 0.040;
    float damagedLine = step(0.982, tapeNoise(vec2(floor(row / 4.0), 25.0)));
    signal = clamp(signal * (scanline - damagedLine * 0.12) + vec3(grain), 0.0, 1.0);
    fragColor = vec4(mix(source.rgb, signal, VHS_INTENSITY), source.a);
}
