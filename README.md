<div align="center">

# 🎮 PlayStation 1 — an Omarchy theme

**Boot-screen blue, the four face-button colors, and a real CRT.**
A retro [Omarchy](https://omarchy.org/) theme channeling the original Sony PlayStation — deep-blue palette, swirling red/green/blue/yellow accents, and a **CRT screen shader** (scanlines, aperture grille, barrel curvature, chromatic aberration) that turns on with the theme.

![PlayStation 1 theme preview — vivid dusk scene with the 16-color palette](docs/preview.jpg)

<sub>Signature wallpaper + the theme's 16-color palette. Desktop screenshots welcome — see [docs/screenshots](docs/screenshots/).</sub>

</div>

---

## ✨ Features

- **PS1 boot-era palette** — deep blue on near-black, driven from a single `colors.toml`.
- **Swirling face-button border** — the active window border cycles ▲ ● ✕ ■ red/green/blue/yellow.
- **Built-in CRT shader** — scanlines, RGB aperture grille, barrel curvature with a black bezel, chromatic aberration, phosphor bloom and vignette. Tuned to read on HiDPI panels. **Auto-applies with the theme; clears when you switch away.**
- **Native install** — the theme *and* the CRT install with Omarchy's one-line theme manager (the shader ships inside the theme).
- **Optional `SUPER+F10` degauss toggle** and an optional themed lock screen.
- Every shader effect is a labeled constant — tune it in seconds.

## 🎨 Palette

| Role | Color | |
|------|-------|--|
| Background | `#0A0A0C` | near-black |
| Accent | `#2E8AE6` | PS blue |
| Red | `#E23B2E` | ● circle |
| Green | `#1FBF61` | ▲ triangle |
| Yellow | `#F5C400` | ■ square / cursor |
| Blue | `#2E8AE6` | ✕ cross |

See `colors.toml` for the full 16-color set.

---

## 🚀 Install

### Option A — Omarchy native (recommended, one line — includes the CRT)

```bash
omarchy theme install https://github.com/Mhsbrian/omarchy-playstation-1-theme.git
```

Installs the theme **with the CRT shader** and applies it. The shader lives
inside the theme and turns on automatically.

### Option B — Script (adds the F10 toggle and/or lock screen)

```bash
git clone https://github.com/Mhsbrian/omarchy-playstation-1-theme.git
cd omarchy-playstation-1-theme

./install.sh                     # theme + CRT
./install.sh --with-crt-toggle   # + SUPER+F10 degauss toggle
./install.sh --all               # + toggle + themed lock screen
```

Then apply:

```bash
omarchy theme set "Playstation 1"
```

Preview any run with `--dry-run`. Details in [docs/INSTALLATION.md](docs/INSTALLATION.md).

## 🗑️ Uninstall

```bash
./uninstall.sh                       # remove theme, CRT, toggle
./uninstall.sh --with-lockscreen     # also restore the default hyprlock flow
```

---

## 📺 The CRT shader

The signature feature. It auto-applies via the theme's `hyprland.conf`
(`decoration:screen_shader`) and reads through `~/.config/omarchy/current/theme/`,
so it's active only while PlayStation 1 is your theme.

- **Toggle live:** `SUPER+F10` (with `--with-crt-toggle`), or
  `hyprctl keyword decoration:screen_shader ""` to clear it by hand.
- **Tune it:** every effect is a labeled constant at the top of
  `shaders/crt-ps1.glsl` — `SCANLINE_STRENGTH`, `CURVE`, `ABERRATION`, … 

Full breakdown, tuning presets (subtle → arcade), and HiDPI notes in
**[docs/CRT-SHADER.md](docs/CRT-SHADER.md)**.

> Requires a Hyprland build supporting `decoration:screen_shader` (GLES 3.0).

---

## 📦 What's in the box

```
colors.toml, hyprland.conf, hyprlock.conf, mako.ini, walker.css, btop.theme,
neovim.lua, icons.theme, backgrounds/, shaders/crt-ps1.glsl   ← theme (repo root)
extras/bin/crt-toggle              ← optional SUPER+F10 toggle
extras/lockscreen/                 ← optional themed Quickshell lock
install.sh · uninstall.sh · lib/   ← installer
docs/                              ← guides, CRT deep-dive, screenshots
```

## 🔒 Optional lock screen

`--with-lockscreen` installs a themed Quickshell lock (a PS1 memory-card look)
that replaces `hyprlock`. It's **invasive** (edits `hypridle.conf`, rebinds
`SUPER+CTRL+L`) but fully reversible, keeps `hyprlock` as a fallback, and backs
up your config first. Test it once at your keyboard before relying on the idle
lock. See [docs/INSTALLATION.md](docs/INSTALLATION.md#optional-lock-screen).

## 📋 Requirements

Omarchy (Hyprland with `decoration:screen_shader`, GLES 3.0). Optional scripts
need `~/.local/bin` on your `$PATH`; the lock screen also needs `quickshell`.

## 📜 License

[MIT](LICENSE). Inspired by the Sony PlayStation boot aesthetic; no Sony assets
are redistributed. "PlayStation" is a trademark of Sony Interactive
Entertainment — this is an unofficial, fan-made color theme.
