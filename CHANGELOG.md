# Changelog

All notable changes to this theme are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions use [SemVer](https://semver.org/).

## [1.2.1] — 2026-07-23

### Changed
- Softer CRT shader defaults (`shaders/crt-ps1.glsl`): nearly-flat screen
  (`CURVE` 0.03 → 0.005) and reduced overall intensity — scanlines 0.28 → 0.17,
  aperture grille 0.18 → 0.10, vignette 0.35 → 0.22, aberration 0.0018 → 0.0010,
  bloom 0.06 → 0.04. Still a bold arcade preset by default; dial the labeled
  constants for more/less.

## [1.2.0] — 2026-07-22

### Added
- **Themed notifications** (`--with-notifications`) — a Quickshell notification
  server rendering desktop notifications as **PS1 BIOS dialogs** (deep-blue
  gradient, four face-button colour strip, double bevel, CRT power-on flicker);
  critical alerts persist with a red border. INVASIVE: it owns the notification
  bus, so it **replaces mako** (reversibly). Installed via a marker-managed
  autostart entry that stops mako and takes the bus; fully restored (mako back)
  by `./uninstall.sh --with-notifications`. Included in `--all`.

### Notes
- Not part of `--with-shell` (that stays the four non-invasive components).

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
- Installer **dependency preflight**: checks the runtime packages the selected
  extras need (`quickshell`, `cava`, `python`), reports which are missing, and —
  with your confirmation — installs them via `sudo pacman`. New `--yes` and
  `--skip-deps` flags; safe under `--dry-run` and throwaway-home tests (never
  invokes `sudo` there).
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
