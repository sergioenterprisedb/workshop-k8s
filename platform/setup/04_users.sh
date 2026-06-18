#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# platform/setup/04_users.sh
# Creates workshop users, copies lab files, distributes the kubeconfig, sets profiles.
# Prerequisites: k3d cluster running with kubeconfig at ~/.kube/config.
# -----------------------------------------------------------------------------
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../config.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/logger.sh"

create_os_user() {
  local username="$1"
  local user_id="${username#${WORKSHOP_USER_PREFIX}}"

  local user_home="/home/${username}"
  local lab_name="cnpg-hands-on"
  local user_lab="${user_home}/${lab_name}"
  local user_manifests="${user_lab}/manifests"

  local src_lab="${WORKSHOP_HOME}/${lab_name}"
  local src_templates="${WORKSHOP_HOME}/platform/resources/manifests"

  log_info "Configuring ${username}"

  # User account
  id "${username}" &>/dev/null || sudo useradd -m -G docker "${username}"

  # Password
  echo "${username}:${WORKSHOP_USER_PASSWORD_PREFIX}${user_id}" | sudo chpasswd

  # Lab files
  sudo cp -r "${src_lab}" "${user_lab}"
  sudo cp -r "${WORKSHOP_HOME}/lib" "${user_home}"
  sudo mkdir -p "${user_manifests}"

  # Generate user manifests from all *-template.yaml files
  for template_file in "${src_templates}"/*-template.yaml; do
    [ -e "$template_file" ] || continue

    local template_name
    local manifest_name
    local output_file

    template_name="$(basename "$template_file")"
    manifest_name="${template_name/-template.yaml/-${username}}"
    output_file="${user_manifests}/${manifest_name}.yaml"

    log_info "Generating ${output_file}"

    USER_NAME="${username}" envsubst < "$template_file" | sudo tee "$output_file" >/dev/null
  done

  # Kubeconfig
  sudo mkdir -p "${user_home}/.kube"
  sudo cp "${HOME}/.kube/config" "${user_home}/.kube/config"

  # Ownership
  sudo chown -R "${username}:${username}" "${user_home}"

  log_success "${username} configured"
}

configure_k8s_user_env() {
  local username="$1" 
  local user_home_dir

  # User paths
  user_home_dir="/home/${username}"

  # Create user namespace
  kubectl create namespace "${username}"

  # Set the namespace as default
  sudo tee "${user_home_dir}/.bash_profile" >/dev/null <<EOF
cd ~/cnpg-hands-on
kubectl config set-context --current --namespace="${username}
EOF

  # Generate minio secrets in user namespace
  kubectl create secret generic minio-secret \
            --from-literal=MINIO_ACCESS_KEY="${MINIO_ROOT_USER}" \
            --from-literal=MINIO_SECRET_KEY="${MINIO_ROOT_PASSWORD}" \
            --namespace="${username}"

  sudo chown -R "${username}:${username}" "${user_home_dir}"
}

main() {
  cd "$(dirname "${BASH_SOURCE[0]}")"

  init_logger
  log_section "Setting up ${TOTAL_USERS} workshop users"

  local i username

  for ((i = 1; i <= TOTAL_USERS; i++)); do
    username="${WORKSHOP_USER_PREFIX}${i}"
    create_os_user "${username}"
    configure_k8s_user_env "${username}"
  done

  log_success "All ${TOTAL_USERS} users configured"
  finalize_logger
}

main "$@"