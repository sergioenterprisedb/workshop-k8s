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
Step 10 - Perform a PostgreSQL Major Upgrade

In this step, you will perform a PostgreSQL major upgrade using CloudNativePG without 
interrupting the source cluster. Unlike a minor upgrade, a major PostgreSQL upgrade 
cannot be performed in place without interruption. CloudNativePG creates a new cluster 
running the target PostgreSQL version and synchronizes it with the source cluster. 
This approach allows you to prepare and validate the upgraded environment while 
keeping the original cluster available.

You will review the upgrade manifest, deploy the new cluster, and monitor the 
synchronization process between the source and target clusters.

Objectives

* Understand the difference between PostgreSQL minor and major upgrades
* Explore the CloudNativePG major upgrade workflow
* Deploy a new cluster running a newer PostgreSQL major version
* Observe how data is synchronized from the source cluster
* Monitor the upgrade process using CloudNativePG tools and Grafana
* Understand how CloudNativePG minimizes downtime during major version upgrades
* Validate that the upgraded cluster is ready for use**
  "
  ui_pause
}

play() {
  ui_info "Let's take a look on the manifest, note that it won't be monitored :" 
  ui_command "cat manifests/06-cnpg-cluster-major-upgrade-${USER}.yaml | yq"
  ui_pause
  ui_info "Deploy the manifest :"
  ui_command "kubectl apply -f manifests/06-cnpg-cluster-major-upgrade-${USER}.yaml" 
  ui_pause
  ui_info "Wait for the cluster to be ready, then press CTL+C to return the lab :"
  ui_command "watch -c -n 1 kubectl cnpg status major-upgraded-cnpg-cluster-${USER} --color always"
  ui_pause
  ui_info "Control data in app database, then go to step 11 !"
}

main() {
  clear
  show_instruct
  play
}

main "$@"