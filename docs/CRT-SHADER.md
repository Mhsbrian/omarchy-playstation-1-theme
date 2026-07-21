# The CRT shader

`shaders/crt-ps1.glsl` is a full-screen GLES 3.0 fragment shader applied through
Hyprland's `decoration:screen_shader`. It recreates the look of a consumer CRT
television — the natural habitat of a PlayStation 1.

## How it's wired

The theme's `hyprland.conf` contains:

```conf
decoration {
    screen_shader = $HOME/.config/omarchy/current/theme/shaders/crt-ps1.glsl
}
```

- `$HOME` is expanded by Hyprland; `current/theme` always points at the *active*
  theme, so the shader is live **only while PlayStation 1 is applied** and clears
  automatically when you switch to any other theme.
- Because the shader ships inside the theme, a native
  `omarchy theme install` carries it along — no separate step.

## What it does

| Effect | Constant | Default |
|--------|----------|---------|
| Scanlines (physical-pixel period) | `SCANLINE_PERIOD` / `SCANLINE_STRENGTH` | `3.0` / `0.28` |
| RGB aperture grille | `GRILLE_PERIOD` / `GRILLE_STRENGTH` | `3.0` / `0.18` |
| Barrel curvature + black bezel | `CURVE` | `0.03` |
| Chromatic aberration | `ABERRATION` | `0.0018` |
| Phosphor bloom (midtone lift) | `BLOOM_LIFT` | `0.06` |
| Vignette | `VIGNETTE_STRENGTH` / `VIGNETTE_EXTENT` | `0.35` / `0.85` |

All are labeled constants at the top of the file. Edit, then re-apply (see below).

## Tuning

The defaults are tuned to read on a **HiDPI panel** (e.g. 2880×1800). On a
lower-density display the scanlines will look heavier — reduce `SCANLINE_STRENGTH`
and/or raise `SCANLINE_PERIOD`.

**Subtle (desk-friendly):**
```glsl
SCANLINE_STRENGTH  0.14
GRILLE_STRENGTH    0.08
CURVE              0.015
ABERRATION         0.0009
```

**Arcade (full tube):**
```glsl
SCANLINE_STRENGTH  0.34
GRILLE_STRENGTH    0.22
CURVE              0.05
ABERRATION         0.0026
```

### Applying changes

The shader is read live by Hyprland, but a running shader is cached. After
editing:

```bash
# toggle off then on (if you installed the SUPER+F10 toggle, press it twice)
hyprctl keyword decoration:screen_shader ""
hyprctl keyword decoration:screen_shader "$HOME/.config/omarchy/current/theme/shaders/crt-ps1.glsl"
```

or just re-run `omarchy theme set "Playstation 1"`.

## Toggling on/off

- With `--with-crt-toggle`: **`SUPER+F10`** flips it (handy for pixel-exact work).
- By hand: `hyprctl keyword decoration:screen_shader ""` clears it;
  re-applying the theme brings it back.

## Performance

A screen shader runs every frame over the whole output. The cost is modest on
modern GPUs, but on battery or integrated graphics you may prefer the "subtle"
preset or toggling it off with `SUPER+F10`.

## Compatibility

Needs a Hyprland build with `decoration:screen_shader` and GLES 3.0 (the shader
declares `#version 300 es`). If your screen goes black when the shader loads,
your Hyprland/GPU may not support it — clear it with
`hyprctl keyword decoration:screen_shader ""` and check `hyprland.log`.
