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

# Display a major section header.
# Example:
#   ui_section "CNPG Cluster Deployment"
ui_section() {
  gum style \
    --foreground "#d75fff" \
    --border rounded \
    --bold \
    --padding "0 2" \
    "$1"
}

# Display informational text.
# Example:
#   ui_info "Checking Kubernetes cluster..."
ui_info() {
  gum style --foreground "#00aaff" "$1"
}

# Display a success message.
# Example:
#   ui_success "Cluster is ready"
ui_success() {
  gum style --foreground "#00ff00" --bold "$1"
}

# Display a warning message.
# Example:
#   ui_warn "This operation may take several minutes"
ui_warn() {
  gum style --foreground "#ffaa00" --bold "$1"
}

# Display an error message.
# Example:
#   ui_error "Cluster creation failed"
ui_error() {
  gum style --foreground "#ff0000" --bold "$1"
}

# Display a numbered or named lab step.
# Example:
#   ui_step "1 - Deploy the CNPG cluster"
ui_step() {
  gum style \
    --foreground "#ffffff" \
    --background "#5f00af" \
    --bold \
    --padding "0 1" \
    "STEP $1"
}

# Ask the user to confirm an action.
# Returns:
#   0 = confirmed
#   1 = cancelled
# Example:
#   ui_confirm "Do you want to continue?"
ui_confirm() {
  gum confirm "$1"
}

# Pause the lab flow until the user confirms.
# Example:
#   ui_pause
ui_pause() {
  gum confirm "Continue?"
}

# Ask the user for text input.
# The first argument is used as placeholder text.
# Example:
#   namespace=$(ui_input "Namespace name")
ui_input() {
  gum input --placeholder "$1"
}

# Display a selection menu and print the selected value.
# Example:
#   choice=$(ui_choose "Deploy" "Backup" "Restore")
ui_choose() {
  gum choose "$@"
}

# Display a spinner while running a command.
# Example:
#   ui_spin "Creating cluster..." kubectl apply -f cluster.yaml
ui_spin() {
  local title="$1"
  shift

  gum spin --title "$title" -- "$@"
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

  printf "\n$ "
  ui_type "$cmd" 0.02
  eval "$cmd"
}