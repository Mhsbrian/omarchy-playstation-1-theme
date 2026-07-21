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
#   --with-lockscreen   Also install the themed Quickshell lock screen. INVASIVE:
#                       replaces hyprlock and edits ~/.config/hypr/hypridle.conf.
#                       Fully reversed by ./uninstall.sh --with-lockscreen.
#   --all               Theme + CRT toggle + lock screen.
#   --dry-run           Print actions without changing anything.
#   -h, --help          Show this help.
#
# Tip: the theme + CRT also install natively with:
#   omarchy theme install https://github.com/Mhsbrian/omarchy-playstation-1-theme.git
#
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

# Theme files at the repo root (shaders/ ships inside the theme).
THEME_FILES=(colors.toml hyprland.conf hyprlock.conf mako.ini walker.css btop.theme neovim.lua icons.theme backgrounds shaders)

DO_TOGGLE=0 DO_LOCK=0
usage() { sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-crt-toggle) DO_TOGGLE=1 ;;
    --with-lockscreen) DO_LOCK=1 ;;
    --all)             DO_TOGGLE=1; DO_LOCK=1 ;;
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

info "Installing into ${DEST_HOME} $([[ $DRY_RUN == 1 ]] && echo '(dry-run)')"
comp_theme
[[ $DO_TOGGLE == 1 ]] && comp_toggle
[[ $DO_LOCK == 1 ]] && comp_lockscreen
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
