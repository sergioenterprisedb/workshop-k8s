#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# platform/setup/03_terminal.sh
# Installs and configures ttyd (web terminal) and tmux, registering ttyd as a service.
# Prerequisites: Amazon Linux 2023, ec2-user with sudo rights.
# -----------------------------------------------------------------------------
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../config.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/logger.sh"

TTYD_VERSION="1.7.7"
TTYD_BIN="/usr/local/bin/ttyd"

install_ttyd() {
  log_section "Installing ttyd"
  sudo curl -L \
    "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64" \
    -o "${TTYD_BIN}" >/dev/null 2>&1

  sudo chmod 755 "${TTYD_BIN}"

  log_success "ttyd installed: $(ttyd --version 2>/dev/null)"
}

install_tmux() {
  log_section "Installing tmux"
  sudo dnf install -y tmux >/dev/null 2>&1

  sudo tee /etc/tmux.conf >/dev/null <<'EOF'
# Global tmux configuration

unbind C-b
set -g prefix C-Space
bind C-Space send-prefix

# Pane splitting
bind Enter split-window -v -c "#{pane_current_path}"
bind BSpace split-window -h -c "#{pane_current_path}"

# Pane navigation
bind Left  select-pane -L
bind Right select-pane -R
bind Up    select-pane -U
bind Down  select-pane -D

# Pane resizing
bind -r C-Left  resize-pane -L 5
bind -r C-Right resize-pane -R 5
bind -r C-Up    resize-pane -U 2
bind -r C-Down  resize-pane -D 2

# Mouse support
set -g mouse on
unbind -n MouseDown3Pane

# History
set-option -g history-limit 50000

# Start indexing at 1
set -g base-index 1
setw -g pane-base-index 1

# Reload configuration
bind r source-file /etc/tmux.conf \; display-message "Configuration reloaded"

# Status bar
set -g status-bg black
set -g status-fg white
EOF

  sudo tee /etc/profile.d/workshop_prompt.sh >/dev/null <<'EOF'
if [ -n "$BASH_VERSION" ] && [ -n "$PS1" ]; then
  export PS1='\[\e[1;32m\]\u@\h \[\e[1;34m\]\w\[\e[0m\] \$ '
  alias ls='ls --color=auto'
  alias grep='grep --color=auto'
fi
EOF

  sudo chmod 644 /etc/profile.d/workshop_prompt.sh

  sudo tee /etc/profile.d/workshop_tmux.sh >/dev/null <<'EOF'
if [ -n "$PS1" ] && [ -z "$TMUX" ] && command -v tmux >/dev/null 2>&1; then
  case "$TERM" in
    xterm*|screen*|tmux*)
      exec tmux
      ;;
  esac
fi
EOF

  sudo chmod 644 /etc/profile.d/workshop_tmux.sh

  log_success "tmux installed: $(tmux -V 2>/dev/null)"
}

configure_ttyd_service() {
  log_section "Configuring ttyd service"
  sudo tee /etc/systemd/system/ttyd.service >/dev/null <<EOF
[Unit]
Description=ttyd Web Terminal
After=network.target

[Service]
User=root
ExecStart=${TTYD_BIN} -p ${TTYD_PORT} -W /bin/login
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload >/dev/null 2>&1

  sudo systemctl enable --now ttyd.service >/dev/null 2>&1

  log_success "ttyd service active on port ${TTYD_PORT}"
}

main() {
  # Ensure relative paths resolve correctly regardless of invocation directory.
  cd "$(dirname "${BASH_SOURCE[0]}")"

  init_logger

  install_ttyd
  install_tmux
  configure_ttyd_service

  finalize_logger
}

main "$@"
