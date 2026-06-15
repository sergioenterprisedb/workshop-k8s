#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# platform/setup/05_cnpg.sh
# Creates baseline setup for CNPG Community installation :
# k cnpg plugin, CNPG Community Operator & CNPG-IO Barman plugin on cp node
# Prerequisites: k3d cluster running with kubeconfig at ~/.kube/config.
# -----------------------------------------------------------------------------
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../config.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/logger.sh"

install_cnpg_plugin(){
 log_section "Installing CNPG kubectl plugin"
 curl -sSfL \
  https://github.com/cloudnative-pg/cloudnative-pg/raw/main/hack/install-cnpg-plugin.sh | \
  sudo sh -s -- -b /usr/local/bin

  cat > kubectl_complete-cnpg <<EOF
#!/usr/bin/env sh

# Call the __complete command passing it all arguments
kubectl cnpg __complete "\$@"
EOF

  chmod +x kubectl_complete-cnpg

  # Important: the following command may require superuser permission
  sudo mv kubectl_complete-cnpg /usr/local/bin
  
  log_success "CNPG kubectl plugin installed"
}

install_cert_manager(){
  log_section "Installing cert-manager"
  helm install \
    cert-manager oci://quay.io/jetstack/charts/cert-manager \
    --version v1.20.2 \
    --namespace cert-manager \
    --create-namespace \
    --set crds.enabled=true
    log_success "cert-manager installed"
}

add_cnpg_repo(){
  helm repo add cnpg https://cloudnative-pg.github.io/charts
  helm repo update
}

install_cnpg_community_operator(){
  log_section "Installing CNPG Community Operator"

  helm upgrade --install cnpg \
  --namespace cnpg-system \
  --create-namespace \
  --set monitoring.podMonitorEnabled=true \
  --set nodeSelector."node\.workshop/role"=platform \
  cnpg/cloudnative-pg

  # When installed via Helm, the default name is cnpg-cloudnative-pg.
  kubectl rollout status deployment   -n cnpg-system cnpg-cloudnative-pg

  log_success "CNPG Community Operator installed"
}

install_cnpg_barman_cloud_plugin(){
  log_section "Installing CNPG Barman Cloud Plugin"

  helm upgrade --install plugin-barman-cloud \
  --namespace cnpg-system \
  --set nodeSelector."node\.workshop/role"=platform \
  cnpg/plugin-barman-cloud

  log_section "CNPG Barman Cloud Plugin installed"
}


main() {
  cd "$(dirname "${BASH_SOURCE[0]}")"

  init_logger

  install_cert_manager
  add_cnpg_repo
  install_cnpg_plugin
  install_cnpg_community_operator
  install_cnpg_barman_cloud_plugin

  finalize_logger
}

main "$@"