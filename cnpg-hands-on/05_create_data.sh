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
In the previous step, you configured the Barman Cloud Plugin and verified that WAL archiving 
was functioning correctly. In this step, you will use CloudNativePG kubectl plugin to navigate 
to your postgres instances. You will understand how connection string can be managed and finally
we will populate data with integrated cnpg pgbench
The goal is not to benchmark PostgreSQL, but to create a controlled workload that generates additional WAL files before performing a backup.

* Use the CloudNativePG plugin to initialize and run a small pgbench workload.
* Explore data
  "
  ui_pause
}

play() {
  ui_info "Let's use cnpg plugin, take a look of available functionalities !" 
  ui_command "kubectl cnpg | grep -A39 \"A plugin to manage your CloudNativePG clusters\""
  ui_pause
  ui_info "We will feed the database with pgbench but how it works :"
  ui_command "kubectl cnpg psql cnpg-cluster-${USER} --dry-run | yq" 
  ui_pause
  ui_info "We have noticed that a connexion String is used : "
  ui_command "kubectl get secrets cnpg-cluster-${USER}-app -o jsonpath=\"{.data.uri}\" | base64 --decode; echo"
  ui_pause
  ui_info "Now we create the database with default value (be careful we are in a mutualized k8s cluster)
pgbench_accounts = 100 000 rows
pgbench_branches = 1 row
pgbench_tellers = 10 rows
pgbench_history = 0 row (feed during the test)  
  "
  ui_command "kubectl cnpg pgbench cnpg-cluster-${USER}"
  ui_pause
  ui_success "Explore your instances, try to find out how to connect to a replica"
  ui_success "Grafana : http://${PUBLIC_IP}:3010 (admin/password)"
  ui_success "Next step we will perform a backup"
}

main() {
  show_instruct
  play
}

main "$@"