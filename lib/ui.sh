#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# ui.sh — Gum UI helpers
# A wrapper on gum tool to build interactive lab scenarios on terminal
# -----------------------------------------------------------------------------

ui_require_gum() {
  if ! command -v gum >/dev/null 2>&1; then
    echo "gum is required but not installed"
    exit 1
  fi
}

ui_section() {
  gum style \
    --foreground "#d75fff" \
    --border rounded \
    --bold \
    --padding "0 2" \
    "$1"
}

ui_info() {
  gum style --foreground "#00aaff" "$1"
}

ui_success() {
  gum style --foreground "#00ff00" --bold "$1"
}

ui_warn() {
  gum style --foreground "#ffaa00" --bold "$1"
}

ui_error() {
  gum style --foreground "#ff0000" --bold "$1"
}

ui_step() {
  gum style \
    --foreground "#ffffff" \
    --background "#5f00af" \
    --bold \
    --padding "0 1" \
    "STEP $1"
}

ui_confirm() {
  gum confirm "$1"
}

ui_pause() {
  gum confirm "Continue?"
}

ui_input() {
  gum input --placeholder "$1"
}

ui_choose() {
  gum choose "$@"
}

ui_spin() {
  local title="$1"
  shift

  gum spin --title "$title" -- "$@"
}

ui_type() {
  local text="$1"
  local delay="${2:-0.03}"

  for ((i = 0; i < ${#text}; i++)); do
    printf "%s" "${text:$i:1}"
    sleep "$delay"
  done

  printf "\n"
}

ui_command() {
  local cmd="$1"

  printf "\n$ "
  ui_type "$cmd" 0.02
  eval "$cmd"
}