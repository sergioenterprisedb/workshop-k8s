#!/bin/bash
# -----------------------------------------------------------------------------
# platform/install.sh
# Runs the platform setup steps in order (system, cluster, terminal, users).
# Prerequisites: Amazon Linux 2023, ec2-user with sudo rights.
# Usage: ./install.sh (run on the EC2 host)
# -----------------------------------------------------------------------------
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../config.sh"

main() {
  # cd to the script's own dir so ./setup/*.sh resolve from any invocation directory.
  cd "$(dirname "${BASH_SOURCE[0]}")"

  if ! ./setup/01_system.sh; then
    exit 1
  fi
  if ! ./setup/02_cluster.sh; then
    exit 1
  fi
  if ! ./setup/03_terminal.sh; then
    exit 1
  fi
  if ! ./setup/04_users.sh; then
    exit 1
  fi
}

main "$@"
