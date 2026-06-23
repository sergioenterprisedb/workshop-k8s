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
In this step, you will trigger a manual backup, and validate the backup process from both Kubernetes and object storage.
  "
  ui_pause
}

play() {
  ui_info "Restoring a cluster in K8S consists of easily set up a new fresh and safe cluster with clean data. 
  * We will perform this operation with a manifest configured to the barman object store, note that this cluster
  will no be monitored in Grafan to simplify the manifest
  * Then you can check the data of the restored cluster
  "
  ui_info "Let's inspect the restored cluster manifest" 
  ui_command "cat manifests/04-cnpg-cluster-restore-${USER}.yaml | yq"
  ui_pause
  ui_info "deploy the manifest :"
  ui_command "k apply -f manifests/04-cnpg-cluster-restore-${USER}.yaml" 
  ui_pause
  ui_info "Check on minio : http://${PUBLIC_IP}:9010 (admin/password) "
  ui_pause
  ui_info "Now we can apply this manifest for a declarative approach : "
  ui_command "cat manifests/03-cnpg-cluster-backup-${USER}.yaml | yq"
  ui_pause
  ui_info "Before applying this manifest, we can explore how it works : "
  ui_command "kubectl explain backups.postgresql.cnpg.io.spec --recursive"
  ui_pause
  ui_info "Let's apply "
  ui_command "kubectl apply -f manifests/03-cnpg-cluster-backup-${USER}.yaml "
  ui_pause
  ui_success "Explore your 2 backups, use kubectl describe to analyze your backups"
  ui_success "Verify that the restored cluster has data and streams it WALs"
}

main() {
  show_instruct
  play
}

main "$@"