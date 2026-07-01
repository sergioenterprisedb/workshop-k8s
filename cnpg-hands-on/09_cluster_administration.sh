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
Step 09 - Administer the Cluster with the CNPG Plugin

In this step, you will use the CloudNativePG kubectl plugin to perform common cluster 
administration operations. You will inspect the available plugin commands, check the 
current role of each PostgreSQL instance, promote a replica to become the new primary, 
hibernate and restart the cluster, and use fencing to safely isolate a PostgreSQL 
instance while keeping its Kubernetes Pod alive.

Objectives

* Explore CloudNativePG administration commands
* Identify primary and replica instances
* Promote a replica to primary
* Hibernate and resume a PostgreSQL cluster
* Understand how fencing isolates an instance without deleting the Pod
* Verify PostgreSQL process status inside a fenced instance
  "
  ui_pause
}

play() {
  ui_info "Let's see again what is proposed by kubectl cnpg plugin commands : "
  ui_command "kubectl cnpg | grep -A39 \"A plugin to manage your CloudNativePG clusters\""
  ui_pause
  ui_info "Before promote a new primary let's check our cnpg cluster instances role :"
  ui_command "kubectl get pods --selector=cnpg.io/cluster=cnpg-cluster-${USER} --label-columns role"
  ui_pause
  REPLICA_POD=$(kubectl get pods --selector=cnpg.io/cluster=cnpg-cluster-"${USER}",role=replica -o jsonpath="{.items[0].metadata.name}")
  ui_info "Let's promote replica ${REPLICA_POD} to be primary"
  ui_command "kubectl cnpg promote cnpg-cluster-${USER} ${REPLICA_POD}"
  ui_pause
  ui_info "Check the cluster to see the new assigned roles"
  ui_command "kubectl get pods --selector=cnpg.io/cluster=cnpg-cluster-${USER} --label-columns role"
  ui_pause
  ui_info "Let's hibernate the cluster and see what happens (CTL+C to exit)"
  ui_command "kubectl cnpg hibernate on cnpg-cluster-${USER};watch -n 1 -c kubectl get pods --label-columns role --selector=cnpg.io/cluster=cnpg-cluster-${USER}"
  ui_pause
  ui_info "Let's go out from hibernation (CTL+C to exit)"
  ui_command "kubectl cnpg hibernate off cnpg-cluster-${USER};watch -n 1 -c kubectl get pods --label-columns role --selector=cnpg.io/cluster=cnpg-cluster-${USER}"
  ui_pause
  ui_info "Fencing isolates a PostgreSQL instance by stopping the database process while keeping the Kubernetes pod alive. 
  This allows administrators to investigate or recover an instance safely without deleting it or allowing it to rejoin the cluster automatically."
  ui_pause
  FENCED_POD=$(kubectl get pods --selector=cnpg.io/cluster=cnpg-cluster-"${USER}",role=replica -o jsonpath="{.items[0].metadata.name}")
  ui_info "Let's fencing ${FENCED_POD} !"
  ui_command "kubectl cnpg fencing on cnpg-cluster-${USER} ${FENCED_POD}"
  ui_pause
  ui_info "Check that postgres is stopped : "
  sleep 2
  ui_command "kubectl exec -it ${FENCED_POD} -- pg_ctl status || true"
  ui_pause
  ui_info "Let's fencing it off !"
  ui_command "kubectl cnpg fencing off cnpg-cluster-${USER} ${FENCED_POD}"
  ui_pause
  ui_info "Check that postgres is running : "
  sleep 2
  ui_command "kubectl exec -it ${FENCED_POD} -- pg_ctl status || true"
  ui_pause
  ui_success "Try to do it yourself or go to step 10 !"
}

main() {
  clear
  show_instruct
  play
}

main "$@"