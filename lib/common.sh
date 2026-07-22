#!/usr/bin/env bash
# Shared helpers for the Omarchy Themes install/uninstall scripts.
# Sourced by install.sh and uninstall.sh — not meant to run on its own.

# ── Config (overridable via env for testing) ─────────────────────────────
# DEST_HOME lets the test harness install into a throwaway directory instead
# of the real $HOME. Everything below is derived from it.
: "${DEST_HOME:=$HOME}"
: "${DRY_RUN:=0}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CFG="$DEST_HOME/.config"
OMARCHY_THEMES_DIR="$CFG/omarchy/themes"
HYPR_DIR="$CFG/hypr"
SHADERS_DIR="$HYPR_DIR/shaders"
QS_DIR="$CFG/quickshell"
BIN_DIR="$DEST_HOME/.local/bin"

BINDINGS="$HYPR_DIR/bindings.conf"
HYPRIDLE="$HYPR_DIR/hypridle.conf"
AUTOSTART="$HYPR_DIR/autostart.conf"

# ── Pretty logging ───────────────────────────────────────────────────────
_c_blue=$'\e[34m'; _c_green=$'\e[32m'; _c_yellow=$'\e[33m'; _c_red=$'\e[31m'; _c_dim=$'\e[2m'; _c_off=$'\e[0m'
info()  { printf '%s==>%s %s\n' "$_c_blue"  "$_c_off" "$*"; }
ok()    { printf '%s  ✓%s %s\n' "$_c_green" "$_c_off" "$*"; }
warn()  { printf '%s  !%s %s\n' "$_c_yellow" "$_c_off" "$*" >&2; }
err()   { printf '%s  ✗%s %s\n' "$_c_red"   "$_c_off" "$*" >&2; }
step()  { printf '%s    %s%s\n' "$_c_dim" "$*" "$_c_off"; }

# ── Dry-run-aware primitives ─────────────────────────────────────────────
# Every mutation goes through run(); with DRY_RUN=1 it only prints.
run() {
  if [[ $DRY_RUN == 1 ]]; then
    printf '%s    [dry-run] %s%s\n' "$_c_dim" "$*" "$_c_off"
  else
    "$@"
  fi
}

# Copy a directory tree (dir contents) to a destination, creating parents.
install_dir() {
  local src="$1" dest="$2"
  run mkdir -p "$dest"
  run cp -rT "$src" "$dest"
}

# Copy a single file, creating parent dirs; optional mode.
install_file() {
  local src="$1" dest="$2" mode="${3:-}"
  run mkdir -p "$(dirname "$dest")"
  run cp -f "$src" "$dest"
  [[ -n $mode ]] && run chmod "$mode" "$dest"
  return 0
}

# One-time timestamped-ish backup of a file before we edit it. Idempotent:
# the .orig backup is written only on the first install so uninstall can
# always find a pristine reference. Returns 0 even if the file is absent.
backup_once() {
  local file="$1" bak="$1.omarchy-themes.orig"
  [[ -f $file ]] || return 0
  if [[ ! -f $bak ]]; then
    run cp -f "$file" "$bak"
    step "backed up $(basename "$file") → $(basename "$bak")"
  fi
}

# ── Marker-managed config blocks (for append-style edits) ────────────────
# A block is delimited so uninstall can remove EXACTLY what we added, and
# install can re-add idempotently. NAME is a short slug.
block_begin() { printf '# >>> omarchy-themes:%s >>> (managed — do not edit inside)\n' "$1"; }
block_end()   { printf '# <<< omarchy-themes:%s <<<\n' "$1"; }

block_present() {
  local file="$1" name="$2"
  [[ -f $file ]] && grep -q "omarchy-themes:$name >>>" "$file"
}

# remove_block FILE NAME — delete the marked block (inclusive) if present.
remove_block() {
  local file="$1" name="$2"
  [[ -f $file ]] || return 0
  block_present "$file" "$name" || return 0
  if [[ $DRY_RUN == 1 ]]; then
    step "[dry-run] remove block '$name' from $(basename "$file")"
  else
    sed -i "/# >>> omarchy-themes:$name >>>/,/# <<< omarchy-themes:$name <<</d" "$file"
    # Normalize whitespace left behind: `cat -s` squeezes repeated blank lines
    # to one; $() strips trailing blanks; printf restores a single final newline.
    local body; body="$(cat -s "$file")"
    printf '%s\n' "$body" >"$file"
  fi
}

# append_block FILE NAME CONTENT — (re)write the marked block at end of file.
append_block() {
  local file="$1" name="$2" content="$3"
  run mkdir -p "$(dirname "$file")"
  [[ -f $file ]] || run touch "$file"
  remove_block "$file" "$name"          # ensure idempotent (no duplicates)
  if [[ $DRY_RUN == 1 ]]; then
    step "[dry-run] append block '$name' to $(basename "$file")"
  else
    { printf '\n'; block_begin "$name"; printf '%s\n' "$content"; block_end "$name"; } >>"$file"
  fi
}

# ── Quickshell component helpers (visualizer / launcher / power / overview) ──
# Each component is a self-contained `qs -c NAME` config that reads the active
# theme's colors.toml and adapts. They share theme-fx/ (shaders used by each
# component's ThemeChrome.qml). Install = copy dir + shared fx, wire a keybind
# and an autostart line, and launch it live; uninstall reverses all of that.
QS_FX_DONE=0

# rm_path PATH — remove a file/dir/symlink if present (dry-run aware).
rm_path() { [[ -e $1 || -L $1 ]] && run rm -rf "$1" || true; }

# is_live_env — true only for a real (non-dry-run) install into the actual $HOME.
is_live_env() { [[ $DRY_RUN == 0 && $DEST_HOME == "$HOME" ]]; }

# install_theme_fx — copy the shared shader/effects dir (once per run).
install_theme_fx() {
  [[ $QS_FX_DONE == 1 ]] && return 0
  install_dir "$REPO_ROOT/extras/quickshell/theme-fx" "$QS_DIR/theme-fx"
  QS_FX_DONE=1
}

# qs_kill NAME — stop a running `qs -c NAME` daemon. Matches /proc cmdline (NUL-
# separated → tr to spaces) rather than `pkill -f`, which would also match this
# script. No-op unless we're on the live host.
qs_kill() {
  is_live_env || return 0
  local pid
  for pid in $(pgrep -x qs 2>/dev/null || true); do
    if tr '\0' ' ' </proc/"$pid"/cmdline 2>/dev/null | grep -q -- " -c $1 "; then
      kill "$pid" 2>/dev/null || true
    fi
  done
}

# qs_launch NAME — (re)start a quickshell config detached on the live host.
qs_launch() {
  is_live_env || return 0
  command -v qs >/dev/null || return 0
  qs_kill "$1"
  setsid qs -n -d -c "$1" >/dev/null 2>&1 < /dev/null & disown 2>/dev/null || true
  step "launched: qs -c $1"
}

# append_autostart NAME — add the Hyprland exec-once line for a qs config.
append_autostart() {
  append_block "$AUTOSTART" "autostart-$1" "exec-once = uwsm-app -- qs -n -d -c $1"
}

# qs_bindings NAME — echo the bindings.conf block for a component.
qs_bindings() {
  case "$1" in
    launcher) cat <<'EOF'
# Themed Quickshell app launcher (overrides Omarchy's walker on SUPER+Space)
unbind = SUPER, SPACE
bindd = SUPER, SPACE, App launcher, exec, qs -c launcher ipc call launcher toggle
bindd = SUPER, D, App launcher, exec, qs -c launcher ipc call launcher toggle
EOF
      ;;
    power) cat <<'EOF'
# Themed Quickshell session / power menu (overrides Omarchy's system menu)
unbind = SUPER, ESCAPE
bindd = SUPER, Escape, Power menu, exec, qs -c power ipc call power toggle
EOF
      ;;
    overview) cat <<'EOF'
# Workspace overview (Quickshell mini-map)
bindd = SUPER, E, Workspace overview, exec, qs -c overview ipc call overview toggle
EOF
      ;;
    visualizer) cat <<'EOF'
# Audio visualizer (Quickshell) — toggle the spectrum strip
bindd = SUPER, M, Audio visualizer, exec, qs -c visualizer ipc call visualizer toggle
EOF
      ;;
  esac
}

# install_qs_component NAME — copy dir + shared fx, wire keybind + autostart, launch.
install_qs_component() {
  local name="$1"
  install_theme_fx
  install_dir "$REPO_ROOT/extras/quickshell/$name" "$QS_DIR/$name"
  append_block "$BINDINGS" "$name" "$(qs_bindings "$name")"
  append_autostart "$name"
  qs_launch "$name"
}

# remove_qs_component NAME — reverse install_qs_component. Shared theme-fx is
# left in place; prune_theme_fx removes it once nothing else needs it.
remove_qs_component() {
  local name="$1"
  qs_kill "$name"
  rm_path "$QS_DIR/$name"
  remove_block "$BINDINGS" "$name"
  remove_block "$AUTOSTART" "autostart-$name"
}

# prune_theme_fx — drop the shared shader dir only if no consumer remains (any
# qs component or the lock screen still installed → keep it).
prune_theme_fx() {
  local c
  for c in visualizer launcher power overview lock; do
    [[ -d "$QS_DIR/$c" ]] && return 0
  done
  rm_path "$QS_DIR/theme-fx"
}

# ── Dependency preflight ─────────────────────────────────────────────────
# The installer records the runtime binaries each selected extra needs with
# require_dep BIN PKG, then calls preflight_deps to report status and — for
# anything missing — offer to install the packages via sudo pacman. Honors
# SKIP_DEPS=1 (--skip-deps) and ASSUME_YES=1 (--yes/-y).
declare -A DEP_PKG=()   # binary -> pacman package that provides it
DEP_WHY=""              # optional trailing note (unused hook)

# require_dep BIN PKG — record that BIN is needed, provided by pacman package PKG.
require_dep() { DEP_PKG["$1"]="$2"; }

# preflight_deps — verify recorded dependencies; install missing ones on request.
preflight_deps() {
  [[ ${SKIP_DEPS:-0} == 1 ]] && { info "Dependency check skipped (--skip-deps)"; return 0; }
  [[ ${#DEP_PKG[@]} -eq 0 ]] && return 0

  info "Checking dependencies"
  local bin pkg width=0
  for bin in "${!DEP_PKG[@]}"; do [[ ${#bin} -gt $width ]] && width=${#bin} || true; done

  local -a missing=()
  while IFS= read -r bin; do
    pkg="${DEP_PKG[$bin]}"
    if command -v "$bin" >/dev/null 2>&1; then
      printf '%s  ✓%s %-*s %sfound%s\n'   "$_c_green"  "$_c_off" "$width" "$bin" "$_c_dim"    "$_c_off"
    else
      printf '%s  ✗%s %-*s %smissing%s  (package: %s)\n' "$_c_red" "$_c_off" "$width" "$bin" "$_c_yellow" "$_c_off" "$pkg"
      missing+=("$pkg")
    fi
  done < <(printf '%s\n' "${!DEP_PKG[@]}" | sort)

  if [[ ${#missing[@]} -eq 0 ]]; then
    ok "all dependencies satisfied"
    return 0
  fi

  # de-duplicate the package list (two binaries can share a package)
  local -a pkgs=(); local p
  while IFS= read -r p; do pkgs+=("$p"); done < <(printf '%s\n' "${missing[@]}" | sort -u)

  echo
  warn "${#pkgs[@]} package(s) not installed: ${pkgs[*]}"

  # Never touch the real system in a dry-run or a throwaway-home test.
  if [[ $DRY_RUN == 1 || $DEST_HOME != "$HOME" ]]; then
    step "[dry-run] would install:  sudo pacman -S --needed ${pkgs[*]}"
    return 0
  fi
  if ! command -v pacman >/dev/null; then
    warn "pacman not found — install these yourself before using the extras: ${pkgs[*]}"
    return 0
  fi

  local ans="y"
  if [[ ${ASSUME_YES:-0} != 1 ]]; then
    printf '%s==>%s Install now with:  %ssudo pacman -S --needed %s%s\n' "$_c_blue" "$_c_off" "$_c_dim" "${pkgs[*]}" "$_c_off"
    printf '    You will be prompted for your sudo password.\n'
    read -r -p "    Proceed? [Y/n] " ans || ans="n"
  fi
  case "${ans:-y}" in
    [nN]*) warn "skipped — the affected extras won't run until installed: ${pkgs[*]}"; return 0 ;;
  esac

  info "Installing packages (sudo)…"
  if sudo pacman -S --needed --noconfirm "${pkgs[@]}"; then
    ok "dependencies installed: ${pkgs[*]}"
  else
    warn "package install failed or was cancelled — install manually: ${pkgs[*]}"
  fi
}
