# Changelog

All notable changes to this theme are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions use [SemVer](https://semver.org/).

## [1.1.0] — 2026-07-21

### Added
- **Optional Quickshell desktop suite** as installable extras, each with a
  keybind + autostart entry and a fully reversible installer:
  - **Audio visualizer** (`SUPER+M`) — a `cava`-driven bottom-edge spectrum that,
    on PlayStation, renders as a *flowing current of the ✕ △ □ ○ glyphs* in the
    four face-button colors, drifting and riding the audio like symbols on water.
    Needs `cava`.
  - **App launcher** (`SUPER+Space` / `SUPER+D`) — fuzzy app search. Needs `python3`.
  - **Power menu** (`SUPER+Escape`) — lock/suspend/logout/restart/shutdown.
  - **Workspace overview** (`SUPER+E`) — mini-map of workspaces and windows.
- New install/uninstall flags: `--with-visualizer`, `--with-launcher`,
  `--with-power`, `--with-overview`, and `--with-shell` (all four). `--all` now
  also includes the suite.
- Shared `extras/quickshell/theme-fx/` shader dir, installed once and pruned on
  uninstall when no component (or the lock screen) still needs it.

### Notes
- Marker-managed keybind + autostart blocks; verified byte-for-byte clean
  uninstall against a throwaway home.

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
