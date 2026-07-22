# Installation guide — PlayStation 1

Two ways to install: Omarchy's native theme manager (fastest, includes the CRT)
or the bundled script (adds the F10 toggle and optional lock screen).

---

## 1. Native install (theme + CRT)

```bash
omarchy theme install https://github.com/Mhsbrian/omarchy-playstation-1-theme.git
```

Omarchy clones the repo into `~/.config/omarchy/themes/playstation-1` and applies
it. The CRT shader ships inside the theme and turns on automatically. That's the
whole experience — the script below only adds convenience extras.

## 2. Script install

```bash
git clone https://github.com/Mhsbrian/omarchy-playstation-1-theme.git
cd omarchy-playstation-1-theme
./install.sh [options]
```

| Command | Installs |
|---------|----------|
| `./install.sh` | PlayStation 1 theme + CRT shader |
| `./install.sh --with-crt-toggle` | + `SUPER+F10` degauss toggle |
| `./install.sh --with-lockscreen` | + themed lock screen |
| `./install.sh --with-notifications` | + PS1 BIOS-dialog notifications (**replaces mako**) |
| `./install.sh --with-visualizer` | + audio visualizer (`SUPER+M`, needs `cava`) |
| `./install.sh --with-launcher` | + app launcher (`SUPER+Space` / `SUPER+D`, needs `python3`) |
| `./install.sh --with-power` | + power menu (`SUPER+Escape`) |
| `./install.sh --with-overview` | + workspace overview (`SUPER+E`) |
| `./install.sh --with-shell` | + all four Quickshell components above |
| `./install.sh --all` | theme + toggle + lock screen + Quickshell suite |
| `./install.sh --dry-run …` | print every action, change nothing |

Flags stack freely (e.g. `--with-crt-toggle --with-visualizer --with-power`).

### Runtime dependencies

The Quickshell extras need a few packages: `quickshell` (all four), `cava` (the
visualizer), and `python` (the launcher). `install.sh` checks these up front,
prints exactly what's missing, and — with your confirmation — installs them via
`sudo pacman` (you'll be prompted for your password). Auto-confirm with `--yes`,
or manage them yourself with `--skip-deps`. The check never runs `sudo` under
`--dry-run`.

Apply afterward:

```bash
omarchy theme set "Playstation 1"
```

### Where files go

| Component | Destination |
|-----------|-------------|
| Theme + CRT shader | `~/.config/omarchy/themes/playstation-1/` (incl. `shaders/`) |
| CRT toggle script | `~/.local/bin/crt-toggle` |
| CRT toggle keybind | managed block in `~/.config/hypr/bindings.conf` |
| Lock screen | `~/.config/quickshell/lock/` |
| Lock scripts | `~/.local/bin/rise-lock`, `rise-system-lock` |
| Lock keybind | managed block in `~/.config/hypr/bindings.conf` |
| Lock idle wiring | `~/.config/hypr/hypridle.conf` (reversible) |
| Quickshell component | `~/.config/quickshell/{visualizer,launcher,power,overview}/` |
| Shared shaders | `~/.config/quickshell/theme-fx/` (installed once) |
| Component keybinds | managed blocks in `~/.config/hypr/bindings.conf` |
| Component autostart | managed blocks in `~/.config/hypr/autostart.conf` |

See [CRT-SHADER.md](CRT-SHADER.md) for tuning the shader.

---

## Optional Quickshell suite

`--with-shell` (or the individual `--with-visualizer` / `--with-launcher` /
`--with-power` / `--with-overview` flags) installs standalone Quickshell
components that read the active theme's `colors.toml` and adapt.

**What each adds:** its config under `~/.config/quickshell/<name>/`, a
marker-wrapped keybind block in `bindings.conf`, and a marker-wrapped
`exec-once` line in `autostart.conf`. On the live host the component also starts
immediately. The four share `theme-fx/` (installed once).

| Component | Keybind | Overrides | Extra dependency |
|-----------|---------|-----------|------------------|
| Visualizer | `SUPER+M` | — | `cava` |
| Launcher | `SUPER+Space`, `SUPER+D` | Omarchy's `walker` | `python3` |
| Power menu | `SUPER+Escape` | Omarchy's system menu | — |
| Overview | `SUPER+E` | — | — |

Remove with `./uninstall.sh --with-shell` (or the matching individual flag);
`theme-fx/` is pruned automatically once no component or the lock screen needs it.

---

## Optional lock screen

`--with-lockscreen` replaces `hyprlock` with a themed Quickshell lock screen
(a PlayStation memory-card look).

**What it changes:**
- Adds `~/.config/quickshell/lock/` and the `rise-*` scripts.
- Rebinds `SUPER+CTRL+L` (managed, marker-wrapped block).
- Edits `hypridle.conf` so idle/before-sleep locks use the themed lock, and
  teaches the screensaver guard to detect it. A pristine backup is written to
  `hypridle.conf.omarchy-themes.orig` first.

**Safety:**
- `hyprlock` stays installed as a fallback.
- `./uninstall.sh --with-lockscreen` reverses everything exactly.
- **Test it once at your keyboard** (`SUPER+CTRL+L`) before trusting the idle
  lock. If a lock misbehaves: `Ctrl+Alt+F2` to a TTY, `pkill -f 'qs -c lock'`,
  back with `Ctrl+Alt+F1`.

**Requirements:** `quickshell`, a compositor implementing `ext-session-lock-v1`
(Hyprland does), and `~/.local/bin` on your `$PATH`.

---

## Uninstall

```bash
./uninstall.sh                    # remove theme, CRT shader, F10 toggle
./uninstall.sh --with-lockscreen  # + restore default hyprlock flow
./uninstall.sh --with-shell       # + remove the Quickshell suite
./uninstall.sh --keep-theme --with-shell   # remove only the Quickshell suite
```

If you're removing the active theme, switch to another first — Omarchy runs from
a copy, so the live look lingers until you switch.

## Troubleshooting

- **Screen goes black when the CRT loads** — your Hyprland/GPU may not support
  `decoration:screen_shader` (GLES 3.0). Clear it with
  `hyprctl keyword decoration:screen_shader ""` and check `hyprland.log`.
- **CRT looks too heavy** — you're likely on a lower-DPI display; see the
  "subtle" preset in [CRT-SHADER.md](CRT-SHADER.md).
- **`~/.local/bin is not on your $PATH`** — the toggle/lock scripts won't be
  found until you add it (Omarchy usually has it already).
