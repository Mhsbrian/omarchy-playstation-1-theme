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
