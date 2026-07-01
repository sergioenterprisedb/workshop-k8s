#!/usr/bin/env bash
set -Eeuo pipefail

TOTAL_USERS="${TOTAL_USERS:-10}"
LAB_DIR_NAME="${LAB_DIR_NAME:-cnpg-hands-on}"

OBJECT_STORAGE_BUCKET="${OBJECT_STORAGE_BUCKET:-cnpg}"
S3_ENDPOINT_URL="${S3_ENDPOINT_URL:-http://minio.object-storage.svc.cluster.local:9000}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:-admin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-password}"

echo "Cleaning lab for ${TOTAL_USERS} users..."

for i in $(seq 1 "${TOTAL_USERS}"); do
  namespace="user${i}"

  echo "==== Cleaning ${namespace} ===="

  kubectl delete backups.postgresql.cnpg.io --all -n "${namespace}" --ignore-not-found || true
  kubectl delete jobs.batch --all -n "${namespace}" --ignore-not-found || true
  kubectl delete cronjobs.batch --all -n "${namespace}" --ignore-not-found || true

  kubectl delete clusters.postgresql.cnpg.io --all -n "${namespace}" --ignore-not-found || true

  kubectl wait --for=delete clusters.postgresql.cnpg.io --all \
    -n "${namespace}" \
    --timeout=300s || true

  kubectl run "mc-clean-${namespace}" \
    --rm -i \
    -n "${namespace}" \
    --image=minio/mc \
    --restart=Never \
    --command -- sh -c "
      mc alias set minio ${S3_ENDPOINT_URL} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} >/dev/null &&
      mc rm --recursive --force --versions minio/${OBJECT_STORAGE_BUCKET}/cnpg-cluster-${namespace} >/dev/null 2>&1 || true &&
      mc rm --recursive --force --versions minio/${OBJECT_STORAGE_BUCKET}/restored-cnpg-cluster-${namespace} >/dev/null 2>&1 || true &&
      mc rm --recursive --force --versions minio/${OBJECT_STORAGE_BUCKET}/major-upgraded-cnpg-cluster-${namespace} >/dev/null 2>&1 || true
    " || true

  echo "Done ${namespace}"
done

echo
echo "Final check:"
kubectl get clusters,backups,jobs,cronjobs -A || true

echo
echo "Cleanup completed."