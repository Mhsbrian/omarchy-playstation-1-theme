#!/usr/bin/env bash
# Installer for the PlayStation 1 Omarchy theme.
#
#   ./install.sh [options]
#
# Installs the PlayStation 1 theme. The CRT screen shader ships inside the theme
# and auto-applies when the theme is active — no extra steps. Options:
#
#   --with-crt-toggle   Add a SUPER+F10 keybind + `crt-toggle` script to flip the
#                       CRT shader on/off live (a "degauss" switch).
#   --with-lockscreen   Themed Quickshell lock screen. INVASIVE: replaces hyprlock
#                       and edits ~/.config/hypr/hypridle.conf.
#   --with-visualizer   Audio spectrum strip (SUPER+M). Needs `cava`.
#   --with-launcher     Fuzzy app launcher (SUPER+Space, SUPER+D). Needs python3.
#   --with-power        Session / power menu (SUPER+Escape).
#   --with-overview     Workspace overview mini-map (SUPER+E).
#   --with-shell        All four Quickshell components above.
#   --all               Theme + CRT toggle + lock screen + shell components.
#   --yes, -y           Assume "yes" to the package-install prompt.
#   --skip-deps         Skip the runtime dependency check/install entirely.
#   --dry-run           Print actions without changing anything.
#   -h, --help          Show this help.
#
# Extras that need runtime packages (quickshell, cava, python) are checked first;
# anything missing is listed and — with your confirmation — installed via sudo.
#
# Tip: the theme + CRT also install natively with:
#   omarchy theme install https://github.com/Mhsbrian/omarchy-playstation-1-theme.git
#
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

# Theme files at the repo root (shaders/ ships inside the theme).
THEME_FILES=(colors.toml hyprland.conf hyprlock.conf mako.ini walker.css btop.theme neovim.lua icons.theme backgrounds shaders)

DO_TOGGLE=0 DO_LOCK=0 DO_VIZ=0 DO_LAUNCHER=0 DO_POWER=0 DO_OVERVIEW=0
ASSUME_YES=0 SKIP_DEPS=0
usage() { sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-crt-toggle) DO_TOGGLE=1 ;;
    --with-lockscreen) DO_LOCK=1 ;;
    --with-visualizer) DO_VIZ=1 ;;
    --with-launcher)   DO_LAUNCHER=1 ;;
    --with-power)      DO_POWER=1 ;;
    --with-overview)   DO_OVERVIEW=1 ;;
    --with-shell)      DO_VIZ=1; DO_LAUNCHER=1; DO_POWER=1; DO_OVERVIEW=1 ;;
    --all)             DO_TOGGLE=1; DO_LOCK=1; DO_VIZ=1; DO_LAUNCHER=1; DO_POWER=1; DO_OVERVIEW=1 ;;
    --yes|-y)          ASSUME_YES=1 ;;
    --skip-deps)       SKIP_DEPS=1 ;;
    --dry-run)         DRY_RUN=1 ;;
    -h|--help)         usage 0 ;;
    *) err "unknown argument: $1"; usage 1 ;;
  esac
  shift
done

is_live() { [[ $DRY_RUN == 0 && $DEST_HOME == "$HOME" ]]; }

comp_theme() {
  info "PlayStation 1 theme (+ in-theme CRT shader)"
  local dest="$OMARCHY_THEMES_DIR/playstation-1" f
  run mkdir -p "$dest"
  for f in "${THEME_FILES[@]}"; do
    [[ -e "$REPO_ROOT/$f" ]] && run cp -rT "$REPO_ROOT/$f" "$dest/$f"
  done
  ok "installed: playstation-1 → $dest (CRT auto-applies with the theme)"
}

comp_toggle() {
  info "CRT degauss toggle (SUPER+F10)"
  install_file "$REPO_ROOT/extras/bin/crt-toggle" "$BIN_DIR/crt-toggle" 755
  append_block "$BINDINGS" crt "$(cat <<'EOF'
# CRT screen shader toggle ("degauss") — for the PlayStation 1 theme
bindd = SUPER, F10, Toggle CRT shader, exec, crt-toggle
EOF
)"
  ok "installed: SUPER+F10 CRT toggle"
}

comp_lockscreen() {
  info "Themed Quickshell lock screen (invasive — replaces hyprlock)"
  install_dir  "$REPO_ROOT/extras/lockscreen/quickshell-lock" "$QS_DIR/lock"
  install_file "$REPO_ROOT/extras/lockscreen/bin/rise-lock"        "$BIN_DIR/rise-lock" 755
  install_file "$REPO_ROOT/extras/lockscreen/bin/rise-system-lock" "$BIN_DIR/rise-system-lock" 755
  append_block "$BINDINGS" lock "$(cat <<'EOF'
# Themed Quickshell lockscreen (overrides the default hyprlock binding)
unbind = SUPER CTRL, L
bindd = SUPER CTRL, L, Lock system, exec, rise-system-lock
EOF
)"
  if [[ -f $HYPRIDLE ]]; then
    backup_once "$HYPRIDLE"
    if [[ $DRY_RUN == 1 ]]; then
      step "[dry-run] hypridle: omarchy-system-lock → rise-system-lock + screensaver guard"
    else
      sed -i 's/omarchy-system-lock/rise-system-lock/g' "$HYPRIDLE"
      grep -q "qs .*-c lock" "$HYPRIDLE" || sed -i \
        "s#on-timeout = pidof hyprlock || omarchy-launch-screensaver#on-timeout = pgrep -f 'qs .*-c lock' >/dev/null || pidof hyprlock || omarchy-launch-screensaver#" \
        "$HYPRIDLE"
    fi
  else
    warn "no hypridle.conf — skipping idle-lock wiring (keybind still installed)"
  fi
  ok "installed: lockscreen; hyprlock kept as fallback"
}

# ── Quickshell components (thin wrappers around install_qs_component) ────────
comp_visualizer() {
  info "Audio visualizer (SUPER+M)"
  install_qs_component visualizer
  command -v cava >/dev/null || warn "cava is not installed — the visualizer needs it (e.g. 'omarchy pkg add cava' or 'sudo pacman -S cava')"
  ok "installed: visualizer"
}
comp_launcher() {
  info "App launcher (SUPER+Space, SUPER+D)"
  install_qs_component launcher
  command -v python3 >/dev/null || warn "python3 not found — the launcher's app scan (list-apps.py) needs it"
  ok "installed: launcher"
}
comp_power() {
  info "Session / power menu (SUPER+Escape)"
  install_qs_component power
  ok "installed: power"
}
comp_overview() {
  info "Workspace overview (SUPER+E)"
  install_qs_component overview
  ok "installed: overview"
}

info "Installing into ${DEST_HOME} $([[ $DRY_RUN == 1 ]] && echo '(dry-run)')"

# Verify (and offer to install) the runtime packages the selected extras need.
[[ $DO_LOCK == 1 || $DO_VIZ == 1 || $DO_LAUNCHER == 1 || $DO_POWER == 1 || $DO_OVERVIEW == 1 ]] && require_dep qs quickshell
[[ $DO_VIZ == 1 ]] && require_dep cava cava
[[ $DO_LAUNCHER == 1 ]] && require_dep python3 python
preflight_deps

comp_theme
[[ $DO_TOGGLE == 1 ]] && comp_toggle
[[ $DO_LOCK == 1 ]] && comp_lockscreen
[[ $DO_VIZ == 1 ]] && comp_visualizer
[[ $DO_LAUNCHER == 1 ]] && comp_launcher
[[ $DO_POWER == 1 ]] && comp_power
[[ $DO_OVERVIEW == 1 ]] && comp_overview
if [[ $DO_TOGGLE == 1 || $DO_LOCK == 1 ]]; then
  [[ ":$PATH:" == *":$BIN_DIR:"* ]] || warn "$BIN_DIR is not on \$PATH — installed scripts won't be found until it is."
fi

if is_live; then
  command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1 && step "hyprland reloaded"
  if [[ $DO_LOCK == 1 ]] && command -v hypridle >/dev/null; then
    pkill -x hypridle 2>/dev/null || true
    setsid hypridle >/dev/null 2>&1 < /dev/null & disown 2>/dev/null || true
    step "hypridle restarted"
  fi
fi

echo
ok "Done. Apply with:  omarchy theme set \"Playstation 1\""
if [[ $((DO_VIZ + DO_LAUNCHER + DO_POWER + DO_OVERVIEW)) -gt 0 ]]; then
  info "Quickshell extras are live now and autostart on next login. Keybinds:"
  [[ $DO_VIZ == 1 ]]      && step "SUPER+M       audio visualizer"
  [[ $DO_LAUNCHER == 1 ]] && step "SUPER+Space   app launcher   (also SUPER+D)"
  [[ $DO_POWER == 1 ]]    && step "SUPER+Escape  power menu"
  [[ $DO_OVERVIEW == 1 ]] && step "SUPER+E       workspace overview"
fi
