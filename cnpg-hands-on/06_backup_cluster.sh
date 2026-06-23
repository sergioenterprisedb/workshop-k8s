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
  ui_info "To perform a backup it exists 2 methods :
  * Imperative with the usage of kubectl cnpg backup
  * Declarative with the usage of a manifest based on backups.postgresql.cnpg.io 
  "
  ui_info "Let's try imperative backup method" 
  ui_command "kubectl cnpg backup cnpg-cluster-${USER} --plugin-name=barman-cloud.cloudnative-pg.io --method=plugin"
  ui_pause
  ui_info "Control the backup on K8S :"
  ui_command "kubectl get backups.postgresql.cnpg.io" 
  ui_pause
  ui_info "Check on minio :  "
  ui_command "Minio   : http://${PUBLIC_IP}:9010 (admin/password)"
  ui_pause
  ui_info "Now we can apply this manifest for a declarative approach : "
  ui_command "cat manifests/03-cnpg-cluster-backup-${USER}.yaml | yq"
  ui_pause
  ui_info "Before applying this manifest, we can explore how it works : "
  ui_command "kubectl explain backups.postgresql.cnpg.io.spec --recursive"
  ui_pause
  ui_info "Let's apply "
  ui_command "kubectl apply -f manifests/03-cnpg-cluster-backup-user1.yaml "
  ui_pause
  ui_success "Explore your 2 backups, use kubectl describe to analyze your backups"
  ui_success "Grafana : http://${PUBLIC_IP}:3010 (admin/password)"
  ui_success "Next step we will perform a backup"
}

main() {
  show_instruct
  play
}

main "$@"