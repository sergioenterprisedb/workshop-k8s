#!/bin/bash

source ./config.sh

# Install cert-manager
print_info "\n"
print_info  "\nInstallation Cert-Manager...\n"

print_command "${kubectl_cmd} apply -f \
  https://github.com/cert-manager/cert-manager/releases/download/${cert_manager_version=}/cert-manager.yaml\n"

${kubectl_cmd} apply -f \
  https://github.com/cert-manager/cert-manager/releases/download/${cert_manager_version}/cert-manager.yaml

# Wait for the deployments to be ready
print_info "\n"
print_info "Waiting for cert-manager to be ready...\n"
#${kubectl_cmd} wait --for=condition=Available deployment --all -n cert-manager --timeout=300s
${kubectl_cmd} rollout status deployment -n cert-manager
cmctl check api --wait=2m

# Install barman plugin
print_info "\n"
print_info  "Installation Barman-Plugin...\n"

print_command "${kubectl_cmd} apply -f \
        https://github.com/cloudnative-pg/plugin-barman-cloud/releases/download/${plugin_barman_version}/manifest.yaml\n"

${kubectl_cmd} apply -f \
        https://github.com/cloudnative-pg/plugin-barman-cloud/releases/download/${plugin_barman_version}/manifest.yaml

# Wait for deployment to be ready
print_info "\n"
print_info "Waiting for barman plugin to be ready...\n"
${kubectl_cmd} rollout status deployment \
  -n cnpg-system barman-cloud