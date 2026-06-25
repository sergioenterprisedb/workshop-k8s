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
Step 01 - Welcome to the EDB CloudNativePG Workshop!

This lab will guide you through the deployment and operation of PostgreSQL 
clusters on Kubernetes using CloudNativePG. During the workshop, you will 
deploy clusters, connect to databases, perform backups and restores, execute 
failovers, scale workloads, and explore upgrade scenarios.

Important information:
• Each participant works in a dedicated Kubernetes namespace (yours : ${USER})
• All resources created during the lab are suffixed with your user name : "-${USER}"
• Kubernetes manifests are available in the manifests/ directory

This first script validates your environment and introduces the resources 
available during the workshop. Follow the steps in order, experiment freely, 
and enjoy the workshop!
  "
  ui_pause
}

play() {
  ui_info "Remember that you will deploy in your namespace ! If you lose your namespace context, run :"
  ui_command "kubectl config set-context --current --namespace=${NAMESPACE}"
  ui_pause
  ui_info "Let's see the Kubernetes cluster topology ! "
  ui_command "kubectl get nodes --label-columns=node.workshop/role"
  ui_pause
  ui_info "Let's check CloudNativePG Operator and Barman Cloud PLugin"
  ui_command "kubectl get pods -n cnpg-system -o custom-columns=\"NAME:.metadata.name,STATUS:.status.phase,IP:.status.podIP,NODE:.spec.nodeName\""
  ui_pause
  ui_info "Note that a secret has already been deployed into your namespace to interact with minio"
  ui_command "kubectl get secrets minio-secret -o yaml | yq"
  ui_pause
  ui_info "Visit these URLs : "
  ui_success "Minio   : http://${PUBLIC_IP}:9010 (admin/password)"
  ui_success "Grafana : http://${PUBLIC_IP}:3010 (admin/password)"
  ui_success "Your lab environment is ready. Go to step 02 !"
}

main() {
  clear
  show_instruct
  play
}

main "$@"