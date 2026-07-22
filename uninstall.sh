#!/usr/bin/env bash
# Uninstaller for the PlayStation 1 Omarchy theme. Mirrors install.sh.
#
#   ./uninstall.sh [options]
#
#   --with-lockscreen   Also remove the themed lock screen and restore the
#                       default hyprlock flow (reverses hypridle + keybind).
#   --with-notifications  Remove themed notifications and restore mako.
#   --with-visualizer   Remove the audio visualizer (keybind + autostart).
#   --with-launcher     Remove the app launcher (keybind + autostart).
#   --with-power        Remove the power menu (keybind + autostart).
#   --with-overview     Remove the workspace overview (keybind + autostart).
#   --with-shell        Remove all four Quickshell components above.
#   --keep-theme        Remove only extras; keep the base PlayStation 1 theme.
#   --dry-run           Print actions without changing anything.
#   -h, --help          Show this help.
#
# Removing a theme deletes only its source under ~/.config/omarchy/themes. If it
# is the active theme, switch to another first (Omarchy runs from a copy).
#
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

DO_LOCK=0 KEEP_THEME=0 DO_NOTIF=0 DO_VIZ=0 DO_LAUNCHER=0 DO_POWER=0 DO_OVERVIEW=0
usage() { sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-lockscreen)    DO_LOCK=1 ;;
    --with-notifications) DO_NOTIF=1 ;;
    --with-visualizer)    DO_VIZ=1 ;;
    --with-launcher)      DO_LAUNCHER=1 ;;
    --with-power)         DO_POWER=1 ;;
    --with-overview)      DO_OVERVIEW=1 ;;
    --with-shell)         DO_VIZ=1; DO_LAUNCHER=1; DO_POWER=1; DO_OVERVIEW=1 ;;
    --keep-theme)         KEEP_THEME=1 ;;
    --dry-run)            DRY_RUN=1 ;;
    -h|--help)         usage 0 ;;
    *) err "unknown argument: $1"; usage 1 ;;
  esac
  shift
done

is_live() { [[ $DRY_RUN == 0 && $DEST_HOME == "$HOME" ]]; }
active_theme() { tr '[:upper:] ' '[:lower:]-' <"$CFG/omarchy/current/theme.name" 2>/dev/null || true; }
# rm_path is provided by lib/common.sh

comp_rm_theme() {
  info "Removing PlayStation 1 theme (+ CRT shader)"
  [[ "$(active_theme)" == "playstation-1" ]] && warn "'playstation-1' is the ACTIVE theme — switch themes before/after removing it."
  rm_path "$OMARCHY_THEMES_DIR/playstation-1"   # includes the in-theme shaders/
  ok "removed: playstation-1"
}

comp_rm_toggle() {
  info "Removing CRT toggle"
  rm_path "$BIN_DIR/crt-toggle"
  remove_block "$BINDINGS" crt
  ok "removed: SUPER+F10 CRT toggle"
}

comp_rm_lockscreen() {
  info "Removing lock screen — restoring default hyprlock flow"
  rm_path "$QS_DIR/lock"
  rm_path "$BIN_DIR/rise-lock"
  rm_path "$BIN_DIR/rise-system-lock"
  remove_block "$BINDINGS" lock
  if [[ -f $HYPRIDLE ]]; then
    if [[ $DRY_RUN == 1 ]]; then
      step "[dry-run] hypridle: rise-system-lock → omarchy-system-lock + drop guard"
    else
      sed -i 's/rise-system-lock/omarchy-system-lock/g' "$HYPRIDLE"
      sed -i "s#pgrep -f 'qs .*-c lock' >/dev/null || pidof hyprlock#pidof hyprlock#" "$HYPRIDLE"
    fi
  fi
  ok "removed: lockscreen; hyprlock flow restored"
}

comp_rm_notifications() { info "Removing themed notifications — restoring mako"; remove_notifications; ok "removed: notifications; mako restored"; }
comp_rm_visualizer() { info "Removing audio visualizer"; remove_qs_component visualizer; ok "removed: visualizer"; }
comp_rm_launcher()   { info "Removing app launcher";      remove_qs_component launcher;   ok "removed: launcher"; }
comp_rm_power()      { info "Removing power menu";        remove_qs_component power;      ok "removed: power"; }
comp_rm_overview()   { info "Removing workspace overview"; remove_qs_component overview;  ok "removed: overview"; }

info "Uninstalling from ${DEST_HOME} $([[ $DRY_RUN == 1 ]] && echo '(dry-run)')"
comp_rm_toggle          # always safe: no-op if not installed
[[ $DO_LOCK == 1 ]] && comp_rm_lockscreen
[[ $DO_NOTIF == 1 ]] && comp_rm_notifications
[[ $DO_VIZ == 1 ]] && comp_rm_visualizer
[[ $DO_LAUNCHER == 1 ]] && comp_rm_launcher
[[ $DO_POWER == 1 ]] && comp_rm_power
[[ $DO_OVERVIEW == 1 ]] && comp_rm_overview
# Drop the shared theme-fx dir once nothing (component or lock) needs it.
[[ $((DO_VIZ + DO_LAUNCHER + DO_POWER + DO_OVERVIEW + DO_LOCK)) -gt 0 ]] && prune_theme_fx
[[ $KEEP_THEME == 0 ]] && comp_rm_theme
if is_live; then
  command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1 && step "hyprland reloaded"
  if [[ $DO_LOCK == 1 ]] && command -v hypridle >/dev/null; then
    pkill -x hypridle 2>/dev/null || true
    setsid hypridle >/dev/null 2>&1 < /dev/null & disown 2>/dev/null || true
    step "hypridle restarted"
  fi
fi
echo; ok "Done."
