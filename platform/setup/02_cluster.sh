#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# platform/setup/02_cluster.sh
# Creates the k3d cluster, labels nodes, and installs Prometheus/Grafana and MinIO.
# Prerequisites: Docker running and kubectl/helm/k3d installed (01_system.sh done).
# -----------------------------------------------------------------------------
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../config.sh"

export K3D_CLUSTER="workshop"

create_cluster() {
  # Each agent mounts a dedicated host disk so PostgreSQL pods land on separate
  # physical volumes (local-path storage maps into these /mnt/diskN mounts).
  k3d cluster create "${K3D_CLUSTER}" \
    --servers 1 \
    --agents 3 \
    -v '/mnt/disk1:/var/lib/rancher/k3s/storage@agent:0' \
    -v '/mnt/disk2:/var/lib/rancher/k3s/storage@agent:1' \
    -v '/mnt/disk3:/var/lib/rancher/k3s/storage@agent:2' \
    -p "${GRAFANA_PORT}:${GRAFANA_PORT}@loadbalancer" \
    -p "${MINIO_CONSOLE_PORT}:9001@loadbalancer"

  kubectl get nodes
}

label_nodes() {
  kubectl label node "k3d-${K3D_CLUSTER}-server-0" \
    node-role.kubernetes.io/control-plane=true \
    node.workshop/role=platform \
    datacenter=dc1 \
    --overwrite

  for i in 0 1 2; do
    kubectl label node "k3d-${K3D_CLUSTER}-agent-${i}" \
      node-role.kubernetes.io/worker=true \
      node.workshop/role=postgres \
      datacenter=dc1 \
      --overwrite
  done

  kubectl get nodes --show-labels
}

configure_kubeconfig() {
  mkdir -p "${HOME}/.kube"

  # The command output IS the kubeconfig, so it is written to the file.
  k3d kubeconfig get "${K3D_CLUSTER}" >"${HOME}/.kube/config"
  chmod 600 "${HOME}/.kube/config"
}

install_monitoring() {
  helm repo add prometheus-community \
    https://prometheus-community.github.io/helm-charts

  helm repo update

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
    --set alertmanager.alertmanagerSpec.nodeSelector."node\.workshop/role"=platform

  # Patch instead of apply a manifest to avoid issues with Helm's state management when the chart is upgraded
  kubectl -n monitoring patch svc prometheus-community-grafana \
    --type='json' \
    -p="[ {\"op\":\"replace\",\"path\":\"/spec/type\",\"value\":\"LoadBalancer\"},
          {\"op\":\"replace\",\"path\":\"/spec/ports/0/port\",\"value\":${GRAFANA_PORT}}]"

  # Wait for the Grafana rollout, since the monitoring install does not use --wait.
  kubectl -n monitoring rollout status deployment prometheus-community-grafana \
    --timeout=180s
}

install_minio() {
  helm repo add minio https://charts.min.io/

  helm repo update

  helm upgrade --install minio minio/minio \
    --namespace minio \
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
    --timeout 180s

  # Pod selector matches the one used elsewhere in the project (-l app=minio).
  kubectl -n minio get pods -l app=minio \
    -o jsonpath='{.items[*].status.phase}' | grep -q "Running"
}

main() {
  # Ensure relative paths resolve correctly regardless of invocation directory.
  cd "$(dirname "${BASH_SOURCE[0]}")"

  create_cluster
  label_nodes
  configure_kubeconfig
  install_monitoring
  install_minio
}

main "$@"
