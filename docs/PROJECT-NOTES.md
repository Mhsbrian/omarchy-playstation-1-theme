---
name: quickshell-theme-customizations
description: "Custom CRT shader and Quickshell lockscreen added to the PS1/Morrowind Omarchy themes (ambient wallpaper FX was tried and removed)"
metadata: 
  node_type: memory
  type: project
  originSessionId: b7b9c2b7-beb7-4265-b459-b12ddb28616b
---

Deep-theming layer built on top of [[quickshell-rise-bar]] (2026-07-20). All additive; no omarchy source touched.

**CRT shader (PS1 only):** `~/.config/hypr/shaders/crt-ps1.glsl` (GLES 3.0 — scanlines/aperture-grille/vignette). Bound via `decoration:screen_shader` in `~/.config/omarchy/themes/playstation-1/hyprland.conf`, so it auto-applies on that theme and clears on others. `SUPER+F10` = `crt-toggle` ("degauss", `~/.local/bin/crt-toggle`) toggles live.

**Ambient wallpaper FX (REMOVED 2026-07-20):** Built a transparent fog/mote layer at `~/.config/quickshell/wallpaper/` but the user didn't like it — fully removed (dir deleted, autostart line gone from `~/.config/hypr/autostart.conf`). Don't rebuild unless asked. Lesson if revisited: user needs effects MUCH bolder than default instinct (kept tuning too subtle); and omarchy-theme-set does `mv next-theme → current/theme` (new inode per switch) so a `colors.toml` FileView watch goes stale — reload colors on `theme.name` change instead (theme.name is written in-place, watch survives).

**Lockscreen (replaces hyprlock, FULL cutover):** `~/.config/quickshell/lock/` — WlSessionLock + real PAM (`config: "login"`), themed per PS1/Morrowind. Wrapper `~/.local/bin/rise-system-lock` mirrors omarchy-system-lock's extras (1password lock, kbd reset, brightness off) but launches `qs -c lock`. Wired into `~/.config/hypr/hypridle.conf` (lock_cmd, before_sleep_cmd, both listeners' screensaver-guard + lock) and `SUPER+CTRL+L` in bindings.conf. Standalone: `rise-lock`. Demo (no real lock): `QS_LOCK_DEMO=1 qs -c lock`.
  - **REVERT lock:** in hypridle.conf change `rise-system-lock`→`omarchy-system-lock` (3 spots) and restore the guard line to `pidof hyprlock || omarchy-launch-screensaver`; delete the `unbind/bindd SUPER CTRL, L` block in bindings.conf; `pkill -x hypridle && hypridle`. hyprlock is still installed at /usr/bin/hyprlock.

**Decisions (2026-07-20):** notifications stay mako-backed (Rise NotificationPanel polls makoctl — not replaced); omarchy-theme-hook skipped; theme publishing skipped; no live/animated wallpaper wanted (ambient FX removed, mpvpaper not pursued).
