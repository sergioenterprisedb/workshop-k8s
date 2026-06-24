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
Step 05 - Connect to PostgreSQL and Explore Data

In this step, you will use the CloudNativePG kubectl plugin to interact directly 
with your PostgreSQL cluster. You will discover the capabilities of the plugin, 
learn how CloudNativePG manages database connection strings through Kubernetes Secrets, 
and connect to your PostgreSQL instances. You will then initialize a sample pgbench 
dataset and explore the generated objects within the database.

This step focuses on understanding how to access and interact with PostgreSQL clusters 
managed by CloudNativePG before moving on to backup operations.

Objectives

* Discover the capabilities of the CloudNativePG kubectl plugin
* Understand how database connection strings are managed through Kubernetes Secrets
* Connect to PostgreSQL instances using CloudNativePG tools
* Initialize a sample pgbench dataset
* Explore tables and data created in the PostgreSQL database
* Prepare the environment for the backup exercises in the next step
  "
  ui_pause
}

play() {
  ui_info "Let's use cnpg plugin, take a look of available functionalities !" 
  ui_command "kubectl cnpg | grep -A39 \"A plugin to manage your CloudNativePG clusters\""
  ui_pause
  ui_info "We will feed the database with pgbench but how it works :"
  ui_command "kubectl cnpg pgbench cnpg-cluster-${USER} --dry-run | yq" 
  ui_pause
  ui_info "We have noticed that a connexion String is used : "
  ui_command "kubectl get secrets cnpg-cluster-${USER}-app -o jsonpath=\"{.data.uri}\" | base64 --decode; echo"
  ui_pause
  ui_info "Now we create the tables in app database with default value (be careful we are in a mutualized k8s cluster)
pgbench_accounts = 100 000 rows
pgbench_branches = 1 row
pgbench_tellers = 10 rows
pgbench_history = 0 row (feed during the test)  
  "
  ui_command "kubectl cnpg pgbench --job-name pgb-init cnpg-cluster-${USER} -- --initialize"
  ui_pause
  ui_info "Explore data created in app database (\q to exit):"
  ui_command "kubectl cnpg psq cnpg-cluster-${USER}"
  ui_success "Try to find out how to connect to a replica to check data"
  ui_success "Grafana : http://${PUBLIC_IP}:3010 (admin/password)"
  ui_success "Next step we will perform a backup"
}

main() {
  clear
  show_instruct
  play
}

main "$@"