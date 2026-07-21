# Changelog

All notable changes to this theme are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions use [SemVer](https://semver.org/).

## [1.0.0] — 2026-07-20

### Added
- PlayStation 1 Omarchy theme: full `colors.toml`, `hyprland.conf` (four-color
  swirling border + power-on animation feel), `hyprlock.conf`, `mako.ini`,
  `walker.css`, `btop.theme`, `neovim.lua`, `icons.theme`, and `backgrounds/`.
- In-theme CRT screen shader (`shaders/crt-ps1.glsl`): scanlines, RGB aperture
  grille, barrel curvature with black bezel, chromatic aberration, phosphor
  bloom, vignette. Auto-applies with the theme via `decoration:screen_shader`
  through the `current/theme` path, so a native `omarchy theme install` includes
  it.
- Optional `SUPER+F10` CRT "degauss" toggle (`--with-crt-toggle`).
- Optional themed Quickshell lock screen with reversible installer wiring.
- `install.sh` / `uninstall.sh` with `--with-crt-toggle`, `--with-lockscreen`,
  `--all`, and `--dry-run`; idempotent, with marker-managed config edits and a
  verified clean uninstall.
- Documentation: install guide, CRT shader deep-dive, customization guide,
  project notes.
