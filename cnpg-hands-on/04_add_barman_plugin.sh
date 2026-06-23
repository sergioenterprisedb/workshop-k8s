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
In this step, we will enable WAL archiving to MinIO using the CloudNativePG Barman Cloud Plugin.
This demonstrates the plugin-based architecture of CloudNativePG, where backup and object storage 
integrations are decoupled from the core database operator. 
This design improves flexibility, maintainability, and allows backup capabilities to evolve 
independently of the PostgreSQL cluster.

* Update the Cluster manifest to reference the ObjectStore.
* Apply the configuration changes to the cluster.
* Verify that WAL segments are successfully archived to MinIO.
  "
  ui_pause
}

play() {
  ui_info "We have seen in cnpg-system namespace that barman plugin controller has been deployed. 
  We need to create a manifest for ObjectStorage and update the manifest of the cluster. Let's see :
  "
  ui_command "cat manifests/02-cnpg-cluster-barman-plugin-${USER}.yaml | yq"
  ui_pause
  ui_info "Apply the manifest"
  ui_command "kubectl apply -f manifests/02-cnpg-cluster-barman-plugin-${USER}.yaml"
  ui_pause
  ui_info "Observe the status informations of the cluster and wait until finished, then CTL+C"
  ui_command "watch -c -n 1 kubectl cnpg status cnpg-cluster-${USER} --color always"
  ui_pause
  ui_info "Check the objectstores resource"
  ui_command "kubectl get objectstores.barmancloud.cnpg.io"
  ui_pause
  ui_success "Minio   : http://${PUBLIC_IP}:9010 (admin/password)"
  ui_success "Grafana : http://${PUBLIC_IP}:3010 (admin/password)"
  ui_success "See WAL archives in cnpg minio bucket"
}

main() {
  show_instruct
  play
}

main "$@"