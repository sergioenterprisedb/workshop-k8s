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
In this step, you will deploy your first PostgreSQL cluster using CloudNativePG !

Before creating any resources, we will review the CloudNativePG Custom Resource Definitions (CRDs) 
and examine the cluster manifest used throughout the workshop. Understanding the structure of the 
Cluster resource is essential, as most day-to-day operations in CloudNativePG are performed by modifying 
and applying Kubernetes manifests.

Once the manifest has been reviewed, you will deploy the cluster and monitor its initialization until 
all PostgreSQL instances are running and ready.

By the end of this step, you will understand:
• How CloudNativePG extends Kubernetes through CRDs
• The main sections of a Cluster manifest
• How a PostgreSQL cluster is deployed and managed by the operator
• How to monitor the deployment process
  "
  ui_pause
}

play() {
  ui_info "Let's review the Custom Resource Definitions (CRDs) installed by the CloudNativePG operator and explore the different resource types available."
  ui_command "kubectl get customresourcedefinitions.apiextensions.k8s.io | grep cnpg.io"
  ui_pause
  ui_info "You can study the api resources on https://cloudnative-pg.io/docs/1.29/cloudnative-pg.v1 or use (i.e) :"
  ui_command "kubectl explain clusters.postgresql.cnpg.io.spec | less"
  ui_pause
  ui_info "Let's read our first cnpg cluster manifest, note that the cluster will not be connect to minio |"
  ui_command "cat manifests/01-cnpg-cluster-${USER}.yaml | yq"
  ui_pause
  ui_info "Now it's time to deploy your first Postgres cluster"
  ui_command "kubectl apply -f manifests/01-cnpg-cluster-${USER}.yaml"
  ui_pause
  ui_info "As it take some times, you can control the status of pods or execute this cnpg plugin command :"
  ui_command "kubectl cnpg status cnpg-cluster-${USER}"
  ui_pause
  ui_info "Explore pods status and go to grafana : "
  ui_success "Grafana : http://${PUBLIC_IP}:3010 (admin/password)"
  ui_success "Wait for your pg cluster ready before going to next step !"
}

main() {
  show_instruct
  play
}