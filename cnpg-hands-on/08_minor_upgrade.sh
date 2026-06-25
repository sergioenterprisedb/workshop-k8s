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
Step 08 - Perform a PostgreSQL Minor Upgrade

In this step, you will perform a PostgreSQL minor upgrade on your first CloudNativePG cluster.
You will update the PostgreSQL image version in the cluster manifest and use kubectl diff 
to preview the change before applying it. Once the manifest is applied, the CloudNativePG operator 
will detect the new image and perform an in-place rolling upgrade of the PostgreSQL instances.
You will then monitor the upgrade process using Grafana or the CloudNativePG kubectl plugin.

Objectives

* Understand how minor PostgreSQL upgrades are managed by CloudNativePG
* Preview manifest changes with kubectl diff
* Update the PostgreSQL image version declaratively
* Trigger an in-place rolling upgrade
* Monitor the upgrade status with Grafana and kubectl cnpg status
  "
  ui_pause
}

play() {
  ui_info "kubectl diff allows you to preview the changes that will be applied to a Kubernetes resource before executing the update.
In this example, the only functional change is the PostgreSQL container image version, from 16.4 to 16.5, which will trigger a rolling update 
of the CloudNativePG cluster." 
  ui_command "kubectl diff -f manifests/05-cnpg-cluster-minor-upgrade-${USER}.yaml || true"
  ui_pause
  ui_info "Deploy the manifest :"
  ui_command "kubectl apply -f manifests/05-cnpg-cluster-minor-upgrade-${USER}.yaml" 
  ui_pause
  ui_info "Check on Grafana, observe the rolling upgrade : http://${PUBLIC_IP}:3010 (admin/password)"
  ui_info "Or check with kubectl cnpg status. Then go to step 09 !"
}

main() {
  clear
  show_instruct
  play
}

main "$@"