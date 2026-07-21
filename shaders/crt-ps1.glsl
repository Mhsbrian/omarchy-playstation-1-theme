// CRT shader for the PlayStation 1 Omarchy theme.
// Wired via decoration:screen_shader in the theme's hyprland.conf;
// SUPER+F10 ("degauss") toggles it live via crt-toggle.
//
// Tuned to read clearly on a HiDPI panel (2880x1800 @1.33): scanline and
// grille periods are in PHYSICAL pixels sized to stay visible at high density,
// and effect strengths are bold on purpose. Dial the constants below to taste.
#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float SCANLINE_PERIOD    = 3.0;  // physical px per scanline cycle (bigger = chunkier lines)
const float SCANLINE_STRENGTH  = 0.28; // darkening of the dark line (0.0-1.0)
const float GRILLE_PERIOD      = 3.0;  // physical px per R/G/B triad
const float GRILLE_STRENGTH    = 0.18; // aperture-grille saturation
const float VIGNETTE_STRENGTH  = 0.35; // corner darkening
const float VIGNETTE_EXTENT    = 0.85; // how far the vignette reaches inward
const float CURVE              = 0.03; // barrel distortion (0 = flat, ~0.05 = strong tube)
const float ABERRATION         = 0.0018; // chromatic RGB split at edges
const float BLOOM_LIFT         = 0.06; // phosphor glow: midtone lift
const float PI = 3.14159265;

void main() {
    // Barrel curvature: warp UVs toward a tube. Pixels pushed off-screen go black
    // (the CRT bezel), which sells the effect more than any single filter.
    vec2 uv = v_texcoord;
    vec2 cc = uv - 0.5;
    float dist = dot(cc, cc);
    uv = uv + cc * dist * CURVE * 2.0;

    // out-of-bounds after curvature -> black frame edge
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // Chromatic aberration: sample R/B slightly offset from center outward
    vec2 dir = cc * ABERRATION;
    vec3 color;
    color.r = texture(tex, uv + dir).r;
    color.g = texture(tex, uv).g;
    color.b = texture(tex, uv - dir).b;

    // Phosphor bloom: lift midtones, strongest on bright pixels
    color += BLOOM_LIFT * color * (1.0 - color);

    // Scanlines in physical pixels, softened by a sine, weaker on dark pixels
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    float scan = 0.5 + 0.5 * sin(gl_FragCoord.y * (2.0 * PI / SCANLINE_PERIOD));
    color *= 1.0 - SCANLINE_STRENGTH * scan * (0.4 + 0.6 * luma);

    // Aperture grille: cycle R/G/B emphasis across physical columns
    float triad = mod(gl_FragCoord.x, GRILLE_PERIOD);
    vec3 mask = vec3(1.0 - GRILLE_STRENGTH);
    if (triad < 1.0)       mask.r = 1.0;
    else if (triad < 2.0)  mask.g = 1.0;
    else                   mask.b = 1.0;
    color *= mask;

    // Vignette: radial corner falloff
    float vig = smoothstep(VIGNETTE_EXTENT, 0.2, length(cc) * 1.4142);
    color *= 1.0 - VIGNETTE_STRENGTH * (1.0 - vig);

    fragColor = vec4(color, 1.0);
}
