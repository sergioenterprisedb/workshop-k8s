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
In this step, we simulate a failure on the primary instances and will observe how automatic failover occurs.
  "
  ui_pause
}

play() {
  ui_info "Let's destroy primary pods with its pvc resources" 
  ui_info "Get the name of primary instance"
  ui_command "PRIMARY_POD=$(kubectl get pods --selector=cnpg.io/cluster=cnpg-cluster-"${USER}",role=primary -o jsonpath=\"{.items[0].metadata.name}\")"
  ui_command "echo ${PRIMARY_POD}"
  ui_command "kubectl delete pvc/${PRIMARY_POD},pvc/${PRIMARY_POD}-wal,pod/${PRIMARY_POD} --force"
  ui_pause
  ui_success "Take a look on the cluster with :
  * kubectl get pods --selector=cnpg.io/cluster=cnpg-cluster-${USER} --label-columns role --watch
  * Grafana : http://${PUBLIC_IP}:3010 (admin/password)
  * kubectl cnpg status cluster=cnpg-cluster-${USER}
  "
}

main() {
  show_instruct
  play
}

main "$@"