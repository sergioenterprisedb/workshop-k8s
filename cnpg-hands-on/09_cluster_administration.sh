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
In this step, we will focus on kubectl cnpg plugin and its cluster administration command, especially :
* promote 
* hibernate
* fencing
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
  ui_info "Ensure that we get the name of one replica to promote it, we take the first of the list"
  ui_command "REPLICA_POD=$(kubectl get pods --selector=cnpg.io/cluster=cnpg-cluster-"${USER}",role=replica -o jsonpath=\"{.items[0].metadata.name}\")"
  ui_command "echo ${REPLICA_POD}"
  ui_pause
  ui_info "Let's promote this replica"
  ui_command "kubectl cnpg promote cnpg-cluster-{USER} ${REPLICA_POD}"
  ui_pause
  ui_info "Check the cluster to see the new role"
  ui_command "kubectl get pods --selector=cnpg.io/cluster=cnpg-cluster-${USER} --label-columns role"
  ui_pause
  ui_info "Let's hibernate the cluster and directly see what happens (CTL+C to exit)"
  ui_command "kubectl cnpg hibernate on cnpg-cluster-${USER};watch -n 1 -c kubectl get pods --label-columns role --selector=cnpg.io/cluster=cnpg-cluster-{USER}"
  ui_pause
  ui_info "Let's go out from hibernation (CTL+C to exit)"
  ui_command "kubectl cnpg hibernate off cnpg-cluster-${USER};watch -n 1 -c kubectl get pods --label-columns role --selector=cnpg.io/cluster=cnpg-cluster-{USER}"
  ui_pause
  ui_info "Fencing isolates a PostgreSQL instance by stopping the database process while keeping the Kubernetes pod alive. 
  This allows administrators to investigate or recover an instance safely without deleting it or allowing it to rejoin the cluster automatically."
  ui_info "Get the name of an instance, we choose a replica here, and postgres will be stopped"
  ui_command "REPLICA_POD=$(kubectl get pods --selector=cnpg.io/cluster=cnpg-cluster-"${USER}",role=replica -o jsonpath=\"{.items[0].metadata.name}\")"
  ui_command "echo ${REPLICA_POD}"
  ui_pause
  ui_info "Let's fencing it !"
  ui_command "kubectl cnpg fencing on cnpg-cluster-${USER} ${REPLICA_POD};"
  ui_pause
  ui_info "Check that postgres is stopped : "
  ui_command "k exec -it cnpg-cluster-user1-2 -- pg_ctl status"
  ui_pause
  ui_info "Let's fencing it off !"
  ui_command "kubectl cnpg fencing off cnpg-cluster-${USER} ${REPLICA_POD};"
  ui_pause
  ui_info "Check that postgres is running : "
  ui_command "k exec -it cnpg-cluster-user1-2 -- pg_ctl status"
  ui_pause
  ui_success "Try to do it yourself !"
}

main() {
  show_instruct
  play
}

main "$@"