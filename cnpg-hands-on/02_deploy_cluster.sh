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
Step 02 - Deploy Your First PostgreSQL Cluster

In this step, you will deploy your first PostgreSQL cluster with CloudNativePG.
Before creating the cluster, you will review the CloudNativePG CRDs and examine 
the cluster manifest used in this workshop. Understanding this manifest is important 
because most CloudNativePG operations are performed by updating and applying 
Kubernetes resources.

You will then deploy the cluster and monitor its startup until all PostgreSQL 
instances are running and ready.

Objectives

* Understand how CloudNativePG extends Kubernetes with CRDs
* Explore the main sections of a Cluster manifest
* Deploy a PostgreSQL cluster managed by the operator
* Monitor the cluster deployment and initialization process
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
  clear
  show_instruct
  play
}

main "$@"