#version 440
// PlayStation CRT overlay: fine scanlines + a slow rolling refresh band + faint blue glow.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec4 tint;
};
void main() {
    float scan = 0.5 + 0.5 * sin(gl_FragCoord.y * 2.3);   // ~2px scanlines (physical px)
    float dark = 0.13 * scan;
    float roll = fract(qt_TexCoord0.y * 0.5 - time * 0.06);
    float band = smoothstep(0.46, 0.5, roll) * smoothstep(0.54, 0.5, roll);
    vec3 glow = tint.rgb * (0.05 + 0.16 * band);
    fragColor = vec4(glow, dark) * qt_Opacity;
}
