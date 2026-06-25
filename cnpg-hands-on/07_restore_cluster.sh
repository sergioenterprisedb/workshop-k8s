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
Step 07 - Restore a PostgreSQL Cluster from Backup

In this step, you will restore a new PostgreSQL cluster from the backups stored in MinIO.
CloudNativePG performs recovery by creating a brand-new cluster from a backup source rather 
than restoring data in place. This approach provides a safe and repeatable recovery process 
while preserving the original cluster. You will review the recovery manifest, deploy the 
restored cluster, verify that the data has been recovered successfully, and confirm that 
WAL archiving resumes on the new cluster. Finally, you will scale the restored cluster 
to multiple instances to observe how CloudNativePG manages cluster growth after recovery.

Objectives

* Understand the CloudNativePG recovery workflow
* Restore a new PostgreSQL cluster from a backup stored in object storage
* Explore the recovery manifest configuration
* Verify that application data has been successfully recovered
* Confirm that WAL archiving is active on the restored cluster
* Scale the restored cluster and observe operator-managed replication
* Understand why CloudNativePG recovery creates a new cluster rather than modifying an existing one
  "
  ui_pause
}

play() {
  ui_info "Restoring a cluster in K8S consists of easily set up a new fresh and safe cluster with clean data. 
  * We will perform this operation with a manifest configured to the barman object store, note that this cluster
  will no be monitored in Grafana to simplify the manifest
  * Then you can check the data of the restored cluster
  "
  ui_info "Let's inspect the restored cluster manifest" 
  ui_command "cat manifests/04-cnpg-cluster-restore-${USER}.yaml | yq"
  ui_pause
  ui_info "Deploy the manifest :"
  ui_command "kubectl apply -f manifests/04-cnpg-cluster-restore-${USER}.yaml" 
  ui_pause
  ui_info "Wait for the cluster to be ready, then press CTL+C to return to the lab :"
  ui_command "watch -c -n 1 kubectl cnpg status restored-cnpg-cluster-${USER} --color always"
  ui_pause
  ui_info "Check on minio that the wals are streamed : http://${PUBLIC_IP}:9010 (admin/password) "
  ui_pause
  ui_info "As the restored cluster contains only one instance node, let's scaling it to 3 :"
  ui_command "kubectl scale --replicas=3 cluster/restored-cnpg-cluster-${USER} "
  ui_success "Check and verify that the restored cluster contains data and streams its WALs, go to step 08 !"
}

main() {
  clear
  show_instruct
  play
}

main "$@"