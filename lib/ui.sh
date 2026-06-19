#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# ui.sh — Gum UI helpers
# Wrapper around gum to build interactive terminal-based lab scenarios.
#
# Usage:
#   source ./ui.sh
#   ui_require_gum
#
# Main helpers:
#   ui_section  : display a major section title
#   ui_step     : display a lab step
#   ui_info     : display informational text
#   ui_success  : display a success message
#   ui_warn     : display a warning message
#   ui_error    : display an error message
#   ui_confirm  : ask for yes/no confirmation
#   ui_pause    : pause until user confirms
#   ui_input    : ask for text input
#   ui_choose   : ask user to choose from a list
#   ui_spin     : show spinner while a command runs
#   ui_type     : simulate typing
#   ui_command  : simulate typing a command, then execute it
# -----------------------------------------------------------------------------

# Verify that gum is installed before using the UI helpers.
ui_require_gum() {
  if ! command -v gum >/dev/null 2>&1; then
    echo "gum is required but not installed"
    exit 1
  fi
}

# Display a page, useful for instructions
# Example:
#   ui_note "
#   Instructions:
#   - First step
#   - ...
#   "
ui_note() {
  gum style \
    --border rounded \
    --border-foreground "#64748b" \
    --padding "1 2" \
    --foreground "#cbd5e1" \
    -- "$1"
}

# Display a major section header.
# Example:
#   ui_section "CNPG Cluster Deployment"
ui_section() {
  gum style \
    --foreground "#e2e8f0" \
    --border rounded \
    --border-foreground "#475569" \
    --bold \
    --padding "0 2" \
    -- "$1"
}

# Display informational text.
# Example:
#   ui_info "Checking Kubernetes cluster..."
ui_info() {
  printf "\n"
  gum style \
    --foreground "#94a3b8" \
    -- "$1"
}

# Display a success message.
# Example:
#   ui_success "Cluster is ready"
ui_success() {
  gum style \
    --foreground "#22c55e" \
    --bold \
    -- "✓ $1"
}

# Display a warning message.
# Example:
#   ui_warn "This operation may take several minutes"
ui_warn() {
  gum style \
    --foreground "#f59e0b" \
    --bold \
    -- "⚠ $1"
}

# Display an error message.
# Example:
#   ui_error "Cluster creation failed"
ui_error() {
  gum style \
    --foreground "#ef4444" \
    --bold \
    -- "✗ $1"
}

# Display a numbered or named lab step.
# Example:
#   ui_step "1 - Deploy the CNPG cluster"
ui_step() {
  gum style \
    --foreground "#60a5fa" \
    --bold \
    -- "▶ STEP $1"
}

# Ask the user to confirm an action.
# Returns:
#   0 = confirmed
#   1 = cancelled
# Example:
#   ui_confirm "Do you want to continue?"
ui_confirm() {
  gum confirm \
    --prompt.foreground="#94a3b8" \
    --selected.foreground="#e2e8f0" \
    --selected.background="#334155" \
    --unselected.foreground="#64748b" \
    "$1"
}

# Pause the lab flow until the user confirms.
# Example:
#   ui_pause
ui_pause() {
  printf "\n\033[38;5;214m▶ Press Enter to continue ...\033[0m "
  read -r _
}

# Ask the user for text input.
# The first argument is used as placeholder text.
# Example:
#   namespace=$(ui_input "Namespace name")
ui_input() {
  gum input \
    --prompt.foreground="#94a3b8" \
    --placeholder.foreground="#64748b" \
    --placeholder "$1"
}

# Display a selection menu and print the selected value.
# Example:
#   choice=$(ui_choose "Deploy" "Backup" "Restore")
ui_choose() {
  gum choose \
    --cursor.foreground="#60a5fa" \
    --selected.foreground="#22c55e" \
    "$@"
}

# Display a spinner while running a command.
# Example:
#   ui_spin "Creating cluster..." kubectl apply -f cluster.yaml
ui_spin() {
  local title="$1"
  shift

  gum spin \
    --spinner dot \
    --title.foreground="#94a3b8" \
    --title "$title" \
    -- "$@"
}

# Simulate text being typed character by character.
# Arguments:
#   $1 = text to display
#   $2 = optional delay between characters, default 0.03 seconds
# Example:
#   ui_type "kubectl get pods"
ui_type() {
  local text="$1"
  local delay="${2:-0.03}"

  for ((i = 0; i < ${#text}; i++)); do
    printf "%s" "${text:$i:1}"
    sleep "$delay"
  done

  printf "\n"
}

# Simulate a command being typed, then execute it.
# Useful for guided demonstrations.
# Warning:
#   This uses eval, so only pass trusted commands.
# Example:
#   ui_command "kubectl get pods -A"
ui_command() {
  local cmd="$1"
  local short_host
  local short_pwd

  short_host="$(hostname -s)"
  short_pwd="$(pwd | sed "s|^$HOME|~|")"

  printf "\033[1;32m%s@%s\033[0m \033[1;34m%s\033[0m $ " \
    "$USER" \
    "$short_host" \
    "$short_pwd"

  ui_type "$cmd" 0.05
  eval "$cmd"
}