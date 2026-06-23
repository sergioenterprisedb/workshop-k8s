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
In this step, you will perform a major upgrade in place of PostgreSQL on the first cluster. This upgrade will stop the cluster.
  "
  ui_pause
}

play() {
  ui_info "Let's take a look on the manifest, note that it will be monitored :" 
  ui_command "cat manifests/07-cnpg-cluster-inplace-major-upgrade-${USER}.yaml | yq"
  ui_pause
  ui_info "deploy the manifest :"
  ui_command "k apply -f manifests/07-cnpg-cluster-inplace-major-upgrade-${USER}.yaml" 
  ui_pause
  ui_info "Check on Grafana : http://${PUBLIC_IP}:3010 (admin/password)"
  ui_info "Or check with kubectl cnpg status ..."
}

main() {
  show_instruct
  play
}

main "$@"