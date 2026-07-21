# Customization — PlayStation 1

Colors come from `colors.toml`; the CRT look comes from `shaders/crt-ps1.glsl`.

## Palette

`colors.toml` drives the terminal, bar, `btop`, `walker`, `mako`, `hyprlock`, and
Neovim. The signature PS1 hues:

```toml
accent     = "#2E8AE6"   # PS blue — bar accent
background = "#0A0A0C"   # near-black
color1     = "#E23B2E"   # ● circle (red)
color2     = "#1FBF61"   # ▲ triangle (green)
color3     = "#F5C400"   # ■ square (yellow) / cursor
color4     = "#2E8AE6"   # ✕ cross (blue)
```

After editing, regenerate downstream configs:

```bash
omarchy theme set "Playstation 1"
```

## The swirling border

`hyprland.conf` sets a four-color animated active border (the face-button
colors) plus a "power-on" window animation feel:

```conf
general {
    col.active_border = rgb(E23B2E) rgb(F5C400) rgb(1FBF61) rgb(2E8AE6) 45deg
}
```

The rainbow orbit is driven by a `borderangle` animation set to `loop`. To save
GPU/battery, change `loop` to `once` in `hyprland.conf`, then `hyprctl reload`.

## The CRT shader

See [CRT-SHADER.md](CRT-SHADER.md) — every effect is a labeled constant with
subtle/arcade presets.

## Wallpapers

Add images to `backgrounds/`. Cycle the live wallpaper with `omarchy theme bg
next`. Filenames are ordered by prefix.

## Fonts, icons

- Icons: `icons.theme` names the icon set applied with the theme.
- Fonts are global in Omarchy (`omarchy font set …`), not per-theme.
