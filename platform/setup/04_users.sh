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
  local user_home_dir
  local user_lab_dir
  local src_lab_dir

  # User paths
  user_home_dir="/home/${username}"
  user_lab_dir="${user_home_dir}/cnpg-hands-on"
  user_lab_manifest_dir="${user_lab_dir}/manifests"

  # Source path (admin)
  src_lab_dir="${WORKSHOP_HOME}/cmpg-hands-on"
  src_manifest_templates_dir="${WORKSHOP_HOME}/platform/resources/manifests"

  log_info "Configuring ${username}"

  # User account
  id "${username}" &>/dev/null || sudo useradd -m -G docker "${username}"

  # Password
  local user_id="${username#${WORKSHOP_USER_PREFIX}}"
  echo "${username}:${WORKSHOP_USER_PASSWORD_PREFIX}${user_id}" | sudo chpasswd

  # Lab files
  sudo cp -r "${src_lab_dir}" "${user_lab_dir}"
  sudo mkdir -p "${user_lab_manifest_dir}"

  # Generate user manifests from all *-template.yaml files
  for template_file in "${src_manifest_templates_dir}"/*-template.yaml; do
    [ -e "$template_file" ] || continue

    filename="$(basename "$template_file")"
    output_filename="${filename/-template.yaml/-${username}.yaml}"

    envsubst < "$template_file" > "${user_lab_manifest_dir}/${output_filename}"
  done

  # Kubeconfig + profile
  sudo mkdir -p "${user_home_dir}/.kube"
  sudo cp "${HOME}/.kube/config" "${user_home_dir}/.kube/config"
  sudo chown -R "${username}:${username}" "${user_home_dir}"

  log_success "${username} configured"
}

configure_k8s_user_env() {
  local username="$1" 

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