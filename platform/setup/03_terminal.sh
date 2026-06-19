#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# platform/setup/03_terminal.sh
# Installs and configures ttyd web terminal.
# Prerequisites: Amazon Linux 2023, ec2-user with sudo rights.
# -----------------------------------------------------------------------------
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../config.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/logger.sh"

TTYD_VERSION="1.7.7"
TTYD_BIN="/usr/local/bin/ttyd"

install_ttyd() {
  log_section "Installing ttyd"

  sudo curl -fsSL \
    "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64" \
    -o "${TTYD_BIN}" >/dev/null 2>&1

  sudo chmod 755 "${TTYD_BIN}"

  log_success "ttyd installed: $(${TTYD_BIN} --version 2>/dev/null)"
}

configure_login_banner() {
  log_section "Configuring login banner"

  sudo tee /etc/issue >/dev/null <<'EOF'
Welcome to the CNPG Hands-on Lab

EOF

  log_success "Login banner configured"
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
User=root
ExecStart=${TTYD_BIN} -p ${TTYD_PORT} -W -t title="CNPG Hands-on Lab" /bin/login
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
  configure_login_banner
  configure_shell_profile
  configure_ttyd_service

  finalize_logger
}

main "$@"