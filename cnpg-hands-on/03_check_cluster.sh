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
Step 03 - Explore the PostgreSQL Cluster Resources

In this step, you will inspect the PostgreSQL cluster deployed by CloudNativePG 
and explore the Kubernetes resources created by the operator. You will review the 
cluster status, identify the generated resources, and examine the storage components 
used by the PostgreSQL instances.

Objectives

* Understand how CloudNativePG represents a PostgreSQL cluster in Kubernetes
* Identify the resources automatically created by the operator
* Explore the relationship between Pods, Services, PVCs, and Persistent Volumes
* Understand how PostgreSQL data is stored and persisted in Kubernetes
  "
  ui_pause
}

play() {
  ui_info "First wait until the cluster is ready, it can take 2 minutes, then press CTL+C to return the lab"
  ui_command "watch -c -n 1 kubectl cnpg status cnpg-cluster-${USER} --color always"
  ui_info "Identify Postgres instances pods with their role"
  ui_command "kubectl get pods --selector=cnpg.io/cluster=cnpg-cluster-${USER} --label-columns role"
  ui_pause
  ui_info "Check that they are placed correctly on a different dedicated node"
  ui_command "kubectl get pods --selector=cnpg.io/cluster=cnpg-cluster-${USER} -o custom-columns=\"NAME:.metadata.name,IP:.status.podIP,NODE:.spec.nodeName\""
  ui_pause
  ui_info "Check the services resources deployed to access the cluster"
  ui_command "kubectl get services --selector=cnpg.io/cluster=cnpg-cluster-${USER}"
  ui_pause
  ui_info "Check persistent volume binding and see storage class"
  ui_command "kubectl get persistentvolume"
  ui_pause
  ui_info "Check the logs of the cluster"
  ui_command "kubectl cnpg logs cluster cnpg-cluster-${USER} | jq | tail -n 21"
  ui_pause
  ui_info "Review and check the details of the cluster"
  ui_command "kubectl describe clusters.postgresql.cnpg.io cnpg-cluster-${USER} | less"
  ui_pause
  ui_info "Use cluster custom resource provide by cnpg"
  ui_command "kubectl get clusters.postgresql.cnpg.io"
  ui_success "Grafana : http://${PUBLIC_IP}:3010 (admin/password)"
  ui_success "Explore and go to the step 04 to add backup capabilities"
}

main() {
  clear
  show_instruct
  play
}

main "$@"