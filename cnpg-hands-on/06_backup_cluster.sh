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
Step 06 - Perform and Validate Backups

In this step, you will create PostgreSQL backups using CloudNativePG and validate 
the backup process from both Kubernetes and object storage. You will discover the 
two backup approaches supported by CloudNativePG: the imperative method using the 
kubectl plugin and the declarative method using Kubernetes resources. After creating 
backups, you will inspect their status, review the backup resources created by the 
operator, and verify that the backup artifacts have been successfully stored in MinIO.

Objectives

* Understand the backup mechanisms available in CloudNativePG
* Create a backup using the CloudNativePG kubectl plugin
* Explore the Backup custom resource used for declarative backups
* Monitor backup execution and status from Kubernetes
* Verify backup artifacts in MinIO object storage
* Understand how CloudNativePG integrates backup operations into Kubernetes workflows
  "
  ui_pause
}

play() {
  ui_info "To perform a backup it exists 2 methods :
  * Imperative : usage of kubectl cnpg backup
  * Declarative : usage of a manifest based on backups.postgresql.cnpg.io 
  "
  ui_info "Let's try imperative backup method" 
  ui_command "kubectl cnpg backup cnpg-cluster-${USER} --plugin-name=barman-cloud.cloudnative-pg.io --method=plugin"
  ui_pause
  ui_info "Control the backup status on K8S, it may be in progress :"
  ui_command "kubectl get backups.postgresql.cnpg.io" 
  ui_pause
  ui_info "Check on minio, but wait a few seconds : http://${PUBLIC_IP}:9010 (admin/password)"
  ui_pause
  ui_info "Now we can apply this manifest with a declarative approach : "
  ui_command "cat manifests/03-cnpg-cluster-backup-${USER}.yaml | yq"
  ui_pause
  ui_info "Before applying this manifest, we can explore how it works : "
  ui_command "kubectl explain backups.postgresql.cnpg.io.spec --recursive"
  ui_pause
  ui_info "Let's apply !"
  ui_command "kubectl apply -f manifests/03-cnpg-cluster-backup-${USER}.yaml "
  ui_pause
  ui_success "Explore your 2 backups, use kubectl describe to analyze your backups"
  ui_success "Grafana : http://${PUBLIC_IP}:3010 (admin/password)"
  ui_success "Now we will restore a PostgreSQL cluster from backup, go to step 07 !"
}

main() {
  clear
  show_instruct
  play
}

main "$@"