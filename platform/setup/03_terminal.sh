#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# platform/setup/03_terminal.sh
# Installs and configures ttyd web terminal with a welcome account.
# Prerequisites: Amazon Linux 2023, ec2-user with sudo rights.
# -----------------------------------------------------------------------------
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../config.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/logger.sh"

TTYD_VERSION="1.7.7"
TTYD_BIN="/usr/local/bin/ttyd"
WELCOME_USER="welcome"

install_ttyd() {
  log_section "Installing ttyd"

  sudo curl -fsSL \
    "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64" \
    -o "${TTYD_BIN}" >/dev/null 2>&1

  sudo chmod 755 "${TTYD_BIN}"

  log_success "ttyd installed: $(${TTYD_BIN} --version 2>/dev/null)"
}

configure_welcome_user() {
  log_section "Configuring welcome user"

  if ! id "${WELCOME_USER}" >/dev/null 2>&1; then
    sudo useradd -m -s /bin/bash "${WELCOME_USER}"
  fi

  sudo passwd -l "${WELCOME_USER}" >/dev/null 2>&1 || true

  sudo mkdir -p "/home/${WELCOME_USER}"

  sudo cp -r "${WORKSHOP_HOME}/lib" "/home/${WELCOME_USER}/"
  sudo cp "${WORKSHOP_HOME}/platform/resources/banner.txt" "/home/${WELCOME_USER}/"

  sudo tee "/home/${WELCOME_USER}/.bash_profile" >/dev/null <<'EOF'
clear

source lib/ui.sh

ui_info "$(cat banner.txt)"

echo

ui_note "
Welcome to the Kubernetes and CloudNativePG Hands-on Lab.

You are currently connected with a temporary welcome account only used to display
this welcome page.

• Type 'login' to connect to your lab session.
• Then enter your assigned username and password.

Each participant has a dedicated Linux account and works in their own Kubernetes namespace.
"

alias login='ui_login'

ui_success "Ready when you are."
EOF

  sudo chown -R "${WELCOME_USER}:${WELCOME_USER}" \
    "/home/${WELCOME_USER}/lib" \
    "/home/${WELCOME_USER}/banner.txt" \
    "/home/${WELCOME_USER}/.bash_profile"

  sudo chmod 644 "/home/${WELCOME_USER}/.bash_profile"

  log_success "Welcome user configured"
}

configure_shell_profile() {
  log_section "Configuring shell profile"

  sudo rm -f /etc/profile.d/workshop_tmux.sh

  sudo tee /etc/profile.d/workshop_prompt.sh >/dev/null <<'EOF'
if [ -n "$BASH_VERSION" ] && [ -n "$PS1" ]; then
  export PS1='\[\e[1;32m\]\u@\h \[\e[1;34m\]\w\[\e[0m\] \$ '
  alias ls='ls --color=auto'
  alias grep='grep --color=auto'
fi
EOF

  sudo chmod 644 /etc/profile.d/workshop_prompt.sh

  log_success "Shell profile configured"
}

configure_ttyd_service() {
  log_section "Configuring ttyd service"

  sudo tee /etc/systemd/system/ttyd.service >/dev/null <<EOF
[Unit]
Description=ttyd Web Terminal
After=network.target

[Service]
User=${WELCOME_USER}
Group=${WELCOME_USER}
WorkingDirectory=/home/${WELCOME_USER}
ExecStart=${TTYD_BIN} -p ${TTYD_PORT} -W -t title="CNPG Hands-on Lab" /bin/bash -l
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload >/dev/null 2>&1
  sudo systemctl enable --now ttyd.service >/dev/null 2>&1
  sudo systemctl restart ttyd.service >/dev/null 2>&1

  log_success "ttyd service active on port ${TTYD_PORT}"
}

main() {
  cd "$(dirname "${BASH_SOURCE[0]}")"

  init_logger

  install_ttyd
  configure_welcome_user
  configure_shell_profile
  configure_ttyd_service

  finalize_logger
}

main "$@"