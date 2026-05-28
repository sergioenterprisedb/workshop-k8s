#!/bin/bash
# -----------------------------------------------------------------------------
# platform/scripts/get_status.sh
# Shows the CNPG cluster status for a workshop user (arg: username).
# -----------------------------------------------------------------------------
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../config.sh"

# Ensure relative paths resolve correctly regardless of invocation directory.
cd "$(dirname "${BASH_SOURCE[0]}")"

# Default to empty so an absent argument does not trip `set -u` from config.sh.
username="${1:-}"

kubectl-cnpg -n ns-${username} --color always status cluster-${username}
