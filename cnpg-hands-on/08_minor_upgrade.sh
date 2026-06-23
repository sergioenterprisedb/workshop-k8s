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
In this step, you will perform a minor upgrade of PostgreSQL on the first cluster, simply by updating the image value in the cluster manifest.
CNPG Operator will detect it and perform a rolling upgrade. It is an in place minor upgrade. 
  "
  ui_pause
}

play() {
  ui_info "kubectl diff allows you to preview the changes that will be applied to a Kubernetes resource before executing the update.
In this example, the only functional change is the PostgreSQL container image version, from 16.4 to 16.5, which will trigger a rolling update 
of the CloudNativePG cluster." 
  ui_command "kubectl diff -f manifests/05-cnpg-cluster-minor-upgrade-${USER}.yaml"
  ui_pause
  ui_info "deploy the manifest :"
  ui_command "k apply -f manifests/05-cnpg-cluster-minor-upgrade-${USER}.yaml" 
  ui_pause
  ui_info "Check om Grafana : http://${PUBLIC_IP}:3010 (admin/password)"
  ui_info "Or check with kubectl cnpg status "
}

main() {
  show_instruct
  play
}

main "$@"