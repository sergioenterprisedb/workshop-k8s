#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# cnpg-hands-on/XX_reset_lab.sh
# -----------------------------------------------------------------------------
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${LAB_DIR}/lib/ui.sh"
source "${LAB_DIR}/config.sh"

LAB_USER="${USER}"
NAMESPACE="${LAB_USER}"
PUBLIC_IP="${PUBLIC_IP:-$(curl -fsS https://api.ipify.org || echo "<PUBLIC_IP>")}"

GRAFANA_URL="http://${PUBLIC_IP}:3010"
MINIO_URL="http://${PUBLIC_IP}:9010"

CLUSTERS=(
  "cnpg-cluster-${USER}"
  "restored-cnpg-cluster-${USER}"
  "major-upgraded-cnpg-cluster-${USER}"
)

show_instruct() {
  ui_note "
Reset your lab

If you failed or broke the labs, you can reset your environment by following
this scenario.

Objectives

* Delete CNPG clusters created during the workshop
* Delete MinIO prefixes associated with these clusters
* Start again from a clean environment

Warning

This operation is destructive.
Only resources related to your user will be targeted.
  "
  ui_pause
}

play() {
  local cluster

  ui_info "Your currently deployed resources are:"
  ui_command "kubectl get clusters,backups,jobs -n ${NAMESPACE} || true"
  ui_pause

  if ! ui_confirm "Do you really want to reset your lab?"; then
    ui_warn "Reset cancelled."
    exit 0
  fi

  ui_info "Deleting Backup resources..."

  if kubectl get backups.postgresql.cnpg.io -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -q .; then
    ui_command "kubectl delete backups.postgresql.cnpg.io --all -n ${NAMESPACE}"
  else
    ui_warn "No Backup resources found."
  fi

  ui_info "Deleting Job resources..."

  if kubectl get jobs.batch -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -q .; then
    ui_command "kubectl delete jobs.batch --all -n ${NAMESPACE}"
  else
    ui_warn "No Job resources found."
  fi

  for cluster in "${CLUSTERS[@]}"; do

    ui_info "Checking cluster: ${cluster}"

    if kubectl get cluster.postgresql.cnpg.io "${cluster}" -n "${NAMESPACE}" >/dev/null 2>&1; then

      ui_command "kubectl delete cluster.postgresql.cnpg.io ${cluster} -n ${NAMESPACE}"

      ui_spin "Waiting for cluster deletion..." \
        kubectl wait \
          --for=delete \
          "cluster.postgresql.cnpg.io/${cluster}" \
          -n "${NAMESPACE}" \
          --timeout=300s

      ui_success "Cluster ${cluster} deleted."

    else
      ui_warn "Cluster ${cluster} not found."
    fi

    ui_info "Purging MinIO prefix: ${cluster}"

    if ui_spin "Deleting MinIO objects..." \
      kubectl run mc \
        --rm -i \
        -n "${NAMESPACE}" \
        --image=minio/mc \
        --restart=Never \
        --command -- sh -c "
          mc alias set minio ${S3_ENDPOINT_URL} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} >/dev/null &&
          mc stat minio/${OBJECT_STORAGE_BUCKET}/${cluster} >/dev/null 2>&1 &&
          mc rm --recursive --force --versions minio/${OBJECT_STORAGE_BUCKET}/${cluster}
        "
    then
      ui_success "MinIO prefix ${cluster} removed."
    else
      ui_warn "No MinIO objects found for ${cluster}."
    fi

  done

  ui_info "Final check:"
  ui_command "kubectl get clusters,backups,jobs -n ${NAMESPACE} || true"

  ui_success "Lab reset completed."
}

main() {
  clear
  show_instruct
  play
}

main "$@"