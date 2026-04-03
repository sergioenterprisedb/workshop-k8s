#!/bin/bash

. ../../user0/cnpg-hands-on/commands.sh

# Install helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Prints
print_info "\nInstalling prometheus...\n"
print_command "\nhelm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts\n"

helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts

print_command "\nhelm upgrade --install \
  -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/docs/src/samples/monitoring/kube-stack-config.yaml \
  prometheus-community \
  prometheus-community/kube-prometheus-stack\n"

# Prometheus install
helm upgrade --install \
  -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/docs/src/samples/monitoring/kube-stack-config.yaml \
  prometheus-community \
  prometheus-community/kube-prometheus-stack

# Wait for Prometheus operator
print_info "Waiting for Prometheus Operator to be ready..."
kubectl rollout status deployment/prometheus-community-kube-operator \
  --timeout=300s
# Check status
kubectl --namespace default get pods -l "release=prometheus-community"
kubectl --namespace default get secrets prometheus-community-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
#export POD_NAME=$(kubectl --namespace default get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prometheus-community" -oname)
#kubectl --namespace default port-forward $POD_NAME 3000

# Install service
kubectl apply -f grafana.yaml


# Uninstall prometheus
kubectl get crd
kubectl delete crd prometheuses.monitoring.coreos.com
kubectl delete crd prometheusagents.monitoring.coreos.com
kubectl delete crd prometheusrules.monitoring.coreos.com
kubectl get crd
