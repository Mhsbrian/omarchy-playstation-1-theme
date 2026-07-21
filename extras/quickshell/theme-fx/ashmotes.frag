#version 440
// Morrowind overlay: drifting gold ash motes + a faint warm vignette.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float aspect;
    vec4 gold;
};
float hash(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
void main() {
    vec2 uv = vec2(qt_TexCoord0.x * aspect, qt_TexCoord0.y);
    float m = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        vec2 g = uv * (7.0 + fi * 5.0);
        g.y += time * (0.05 + fi * 0.03);          // motes sink slowly
        vec2 cell = floor(g), f = fract(g);
        float h = hash(cell + fi * 7.0);
        if (h > 0.72) {
            vec2 c = vec2(0.5) + 0.3 * vec2(hash(cell + 1.0), hash(cell + 2.0));
            float d = length(f - c);
            m += smoothstep(0.13, 0.0, d) * (0.55 + 0.45 * sin(time * 1.4 + h * 30.0));
        }
    }
    float vig = 1.0 - smoothstep(0.35, 0.95, length(qt_TexCoord0 - 0.5));
    vec3 col = gold.rgb * (m * 0.9);
    float a = clamp(m * 0.55 + vig * 0.035, 0.0, 0.32);
    fragColor = vec4(col, a) * qt_Opacity;
}
