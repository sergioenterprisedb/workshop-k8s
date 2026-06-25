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
Step 11 - Simulate a Primary Failure

In this step, you will simulate a failure of the primary PostgreSQL instance and observe 
how CloudNativePG performs automatic failover. You will identify the current primary Pod, 
delete it together with its associated PVCs, and then monitor how the operator reacts. 
CloudNativePG will promote a replica as the new primary and reconcile the cluster to 
restore the expected state.

Objectives

* Identify the current primary PostgreSQL instance
* Simulate a failure by removing the primary Pod and its storage
* Observe automatic failover behavior
* Verify that a replica is promoted as the new primary
* Monitor cluster recovery with kubectl, Grafana, and kubectl cnpg status
  "
  ui_pause
}

play() {
  ui_info "Let's check which pod contains the primary instance :" 
  ui_command "kubectl get pods --selector=cnpg.io/cluster=cnpg-cluster-${USER} --label-columns role"
  ui_pause
  PRIMARY_POD=$(kubectl get pods --selector=cnpg.io/cluster=cnpg-cluster-"${USER}",role=primary -o jsonpath=\"{.items[0].metadata.name}\")
  ui_info "Let's destroy the primary pod with its pvc resources"
  ui_command "kubectl delete pvc/${PRIMARY_POD} pvc/${PRIMARY_POD}-wal pod/${PRIMARY_POD} --force"
  ui_pause
  ui_success "Take a look on the cluster with :
  * kubectl get pods --selector=cnpg.io/cluster=cnpg-cluster-${USER} --label-columns role --watch
  * Grafana : http://${PUBLIC_IP}:3010 (admin/password)
  * kubectl cnpg status cluster=cnpg-cluster-${USER}
  Then go to step 12 !
  "
}

main() {
  clear
  show_instruct
  play
}

main "$@"