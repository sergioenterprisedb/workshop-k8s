#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# platform/install.sh
# Runs the platform setup steps in order (system, cluster, terminal, users).
# Prerequisites: Amazon Linux 2023, ec2-user with sudo rights.
# Usage: ./install.sh (run on the EC2 host)
# -----------------------------------------------------------------------------
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../config.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/logger.sh"

main() {
  # cd to the script's own dir so ./setup/*.sh resolve from any invocation directory.
  cd "$(dirname "${BASH_SOURCE[0]}")"

  init_logger
  log_section "Platform installation"

  ./setup/01_system.sh
  ./setup/02_cluster.sh
  ./setup/03_terminal.sh
  ./setup/04_users.sh

  log_success "Platform installation complete"
  finalize_logger
}

main "$@"
