#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# cnpg-hands-on/01_init_environment.sh
# -----------------------------------------------------------------------------
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${LAB_DIR}/lib/ui.sh"

LAB_USER="${USER}"
NAMESPACE="${LAB_USER}"
PUBLIC_IP="${PUBLIC_IP:-$(curl -fsS https://api.ipify.org || echo "<PUBLIC_IP>")}"

GRAFANA_URL="http://${PUBLIC_IP}:3010"
MINIO_URL="http://${PUBLIC_IP}:9010"

show_instruct() {
  ui_note "
Step 12 - Perform an In-Place Major Upgrade

In this step, you will perform an in-place PostgreSQL major upgrade on your first 
CloudNativePG cluster. Unlike the previous major upgrade approach, this method 
upgrades the existing cluster directly. The cluster will be stopped during the 
operation, so this approach involves downtime. You will review the upgrade manifest, 
apply it, and monitor the process using Grafana and kubectl cnpg status.

Objectives

* Understand the in-place major upgrade approach
* Review the upgrade manifest before applying it
* Upgrade the existing PostgreSQL cluster directly
* Observe the cluster downtime during the operation
* Monitor the upgrade process with Grafana and kubectl cnpg status
  "
  ui_pause
}

play() {
  ui_info "Let's take a look on the manifest :" 
  ui_command "cat manifests/07-cnpg-cluster-inplace-major-upgrade-${USER}.yaml | yq"
  ui_pause
  ui_info "Deploy the manifest :"
  ui_command "kubectl apply -f manifests/07-cnpg-cluster-inplace-major-upgrade-${USER}.yaml" 
  ui_pause
  ui_info "Check on Grafana : http://${PUBLIC_IP}:3010 (admin/password)"
  ui_info "Or check with kubectl cnpg status ..."
  ui_info "If everything is working well, congratulations !"
}

main() {
  clear
  show_instruct
  play
}

main "$@"