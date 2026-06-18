#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# platform/setup/02_cluster.sh
# Creates the k3d cluster, labels nodes, and installs Prometheus/Grafana and MinIO.
# Prerequisites: Docker running and kubectl/helm/k3d installed (01_system.sh done).
# -----------------------------------------------------------------------------
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../config.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/logger.sh"

export K3D_CLUSTER="workshop"

create_cluster() {
  log_section "Creating k3d cluster"
  # Each agent mounts a dedicated host disk so PostgreSQL pods land on separate
  # physical volumes (local-path storage maps into these /mnt/diskN mounts).
  sudo k3d cluster create "${K3D_CLUSTER}" \
    --servers 1 \
    --agents 3 \
    -v '/mnt/disk1:/var/lib/rancher/k3s/storage@agent:0' \
    -v '/mnt/disk2:/var/lib/rancher/k3s/storage@agent:1' \
    -v '/mnt/disk3:/var/lib/rancher/k3s/storage@agent:2' \
    -p "${GRAFANA_PORT}:${GRAFANA_PORT}@loadbalancer" \
    -p "${MINIO_CONSOLE_PORT}:9001@loadbalancer" >/dev/null

  log_success "Cluster created: ${K3D_CLUSTER}"

  # Write kubeconfig immediately so kubectl works for the rest of the script
  mkdir -p "${HOME}/.kube"
  sudo k3d kubeconfig get "${K3D_CLUSTER}" > "${HOME}/.kube/config"
  chmod 600 "${HOME}/.kube/config"
  log_success "Kubeconfig written: ${HOME}/.kube/config"
  
  kubectl get nodes >/dev/null
}

label_nodes() {
  log_section "Labelling nodes"
  kubectl label node "k3d-${K3D_CLUSTER}-server-0" \
    node-role.kubernetes.io/control-plane=true \
    node.workshop/role=platform \
    datacenter=dc1 \
    --overwrite >/dev/null 2>&1

  for i in 0 1 2; do
    kubectl label node "k3d-${K3D_CLUSTER}-agent-${i}" \
      node-role.kubernetes.io/worker=true \
      node.workshop/role=postgres \
      datacenter=dc1 \
      --overwrite >/dev/null 2>&1
  done

  kubectl get nodes --show-labels >/dev/null 2>&1
  log_success "Nodes labelled"
}

install_monitoring() {
  log_section "Installing Prometheus and Grafana"
  helm repo add prometheus-community \
    https://prometheus-community.github.io/helm-charts >/dev/null 2>&1

  helm repo update >/dev/null 2>&1

  helm upgrade --install \
    prometheus-community \
    prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/docs/src/samples/monitoring/kube-stack-config.yaml \
    --set grafana.adminUser="${GRAFANA_ADMIN_USER}" \
    --set grafana.adminPassword="${GRAFANA_ADMIN_PASSWORD}" \
    --set grafana.nodeSelector."node\.workshop/role"=platform \
    --set prometheus.prometheusSpec.nodeSelector."node\.workshop/role"=platform \
    --set prometheusOperator.nodeSelector."node\.workshop/role"=platform \
    --set kube-state-metrics.nodeSelector."node\.workshop/role"=platform \
    --set alertmanager.alertmanagerSpec.nodeSelector."node\.workshop/role"=platform >/dev/null 2>&1

  # Patch instead of apply a manifest to avoid issues with Helm's state management when the chart is upgraded
  kubectl -n monitoring patch svc prometheus-community-grafana \
    --type='json' \
    -p="[ {\"op\":\"replace\",\"path\":\"/spec/type\",\"value\":\"LoadBalancer\"},
          {\"op\":\"replace\",\"path\":\"/spec/ports/0/port\",\"value\":${GRAFANA_PORT}}]" >/dev/null 2>&1

  # Wait for the Grafana rollout, since the monitoring install does not use --wait.
  kubectl -n monitoring rollout status deployment prometheus-community-grafana \
    --timeout=180s >/dev/null 2>&1
  log_success "Grafana available on port ${GRAFANA_PORT}"
}

import_cnpg_dashboard() {
  log_section "Importing CNPG dashboard"

  local dashboard_file="${WORKSHOP_HOME}/platform/resources/cnpg-dashboard.json"

  if [ ! -f "${dashboard_file}" ]; then
    log_warn "CNPG dashboard file not found: ${dashboard_file} — skipping"
    return 0
  fi

  # Wait for Grafana API
  for i in {1..30}; do
    if curl -fsS \
      -u "${GRAFANA_ADMIN_USER}:${GRAFANA_ADMIN_PASSWORD}" \
      "http://localhost:${GRAFANA_PORT}/api/health" >/dev/null; then
      log_success "Grafana API is ready"
      break
    fi

    if [ "$i" -eq 30 ]; then
      log_warn "Grafana API not ready — skipping dashboard import"
      return 0
    fi

    sleep 2
  done

  local payload_file
  payload_file=$(mktemp /tmp/grafana-dashboard-payload.XXXXXX.json)

  cat > "${payload_file}" <<EOF
{
  "dashboard": $(cat "${dashboard_file}"),
  "overwrite": true,
  "folderId": 0
}
EOF

  local response=""
  local curl_rc=1

  for i in {1..10}; do
    if response=$(curl -sS -X POST \
      -H "Content-Type: application/json" \
      -u "${GRAFANA_ADMIN_USER}:${GRAFANA_ADMIN_PASSWORD}" \
      --data "@${payload_file}" \
      "http://localhost:${GRAFANA_PORT}/api/dashboards/db"); then
      curl_rc=0
      break
    fi

    log_warn "Grafana dashboard import attempt ${i}/10 failed, retrying in 3s..."
    sleep 3
  done

  rm -f "${payload_file}"

  if [ "${curl_rc}" -ne 0 ]; then
    log_warn "CNPG dashboard import failed after retries — skipping home dashboard config"
    return 0
  fi

  local dashboard_uid
  dashboard_uid=$(printf '%s' "${response}" | \
    python3 -c "import sys,json; print(json.load(sys.stdin).get('uid',''))" \
    2>/dev/null || true)

  if [ -z "${dashboard_uid}" ]; then
    log_warn "CNPG dashboard import failed — skipping home dashboard config"
    log_debug "Grafana response: ${response}"
    return 0
  fi

  log_debug "Dashboard UID: ${dashboard_uid}"

  curl -sS -X PATCH \
    -H "Content-Type: application/json" \
    -u "${GRAFANA_ADMIN_USER}:${GRAFANA_ADMIN_PASSWORD}" \
    -d "{\"homeDashboardUID\": \"${dashboard_uid}\"}" \
    "http://localhost:${GRAFANA_PORT}/api/org/preferences" >/dev/null || true

  log_success "CNPG dashboard imported and set as home dashboard"
}

install_minio() {
  log_section "Installing MinIO"
  helm repo add minio https://charts.min.io/ >/dev/null 2>&1

  helm repo update >/dev/null 2>&1

  helm upgrade --install minio minio/minio \
    --namespace object-storage \
    --create-namespace \
    --set rootUser="${MINIO_ROOT_USER}" \
    --set rootPassword="${MINIO_ROOT_PASSWORD}" \
    --set mode=standalone \
    --set replicas=1 \
    --set persistence.enabled=true \
    --set persistence.size=10Gi \
    --set service.type=LoadBalancer \
    --set consoleService.type=LoadBalancer \
    --set nodeSelector."node\.workshop/role"=platform \
    --wait \
    --timeout 180s >/dev/null 2>&1

  # Pod selector matches the one used elsewhere in the project (-l app=minio).
  kubectl -n object-storage get pods -l app=minio \
    -o jsonpath='{.items[*].status.phase}' | grep -q "Running" >/dev/null 2>&1
  log_success "MinIO available on port ${MINIO_CONSOLE_PORT}"
}

main() {
  # Ensure relative paths resolve correctly regardless of invocation directory.
  cd "$(dirname "${BASH_SOURCE[0]}")"

  init_logger

  create_cluster
  label_nodes
  install_monitoring
  import_cnpg_dashboard
  install_minio

  finalize_logger
}

main "$@"
