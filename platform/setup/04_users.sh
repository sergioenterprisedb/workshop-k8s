#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# platform/setup/04_users.sh
# Creates workshop users, copies lab files, distributes the kubeconfig, sets profiles.
# Prerequisites: k3d cluster running with kubeconfig at ~/.kube/config.
# -----------------------------------------------------------------------------
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../config.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/logger.sh"

main() {
  cd "$(dirname "${BASH_SOURCE[0]}")"

  init_logger
  log_section "Setting up ${TOTAL_USERS} workshop users"

  local i username user_home_dir user_lab_dir

  for ((i = 1; i <= TOTAL_USERS; i++)); do
    username="${WORKSHOP_USER_PREFIX}${i}"
    user_home_dir="/home/${username}"
    user_lab_dir="${user_home_dir}/${WORKSHOP_LAB_DIR_NAME}"

    log_info "Configuring ${username}"

    # User account
    id "${username}" &>/dev/null || sudo useradd -m -G docker "${username}"
    echo "${username}:${WORKSHOP_USER_PASSWORD_PREFIX}${i}" | sudo chpasswd

    # Lab files
    sudo rm -rf "${user_lab_dir}"
    sudo cp -r "${SOURCE_CNP_PATH}" "${user_lab_dir}"
    sudo rm -f \
      "${user_lab_dir}/01_install_plugin.sh" \
      "${user_lab_dir}/02_install_operator.sh" \
      "${user_lab_dir}/03_check_operator_installed.sh" \
      "${user_lab_dir}/04_install_barman_plugin.sh"
    sudo cp "${SOURCE_ADMIN_PATH}/scripts/get_clusters.sh" "${user_lab_dir}/"
    sudo cp "${SOURCE_ADMIN_PATH}/scripts/get_pods.sh" "${user_lab_dir}/"
    sudo cp "${SOURCE_ADMIN_PATH}/scripts/get_status.sh" "${user_lab_dir}/"

    # Kubeconfig + profile
    sudo mkdir -p "${user_home_dir}/.kube"
    sudo cp "${HOME}/.kube/config" "${user_home_dir}/.kube/config"
    sudo tee "${user_home_dir}/.bash_profile" >/dev/null <<EOF
cd ~/${WORKSHOP_LAB_DIR_NAME}
${WORKSHOP_CONTEXT_SCRIPT}
EOF
    sudo chown -R "${username}:${username}" "${user_home_dir}"
    log_success "${username} configured"
  done

  log_success "All ${TOTAL_USERS} users configured"
  finalize_logger
}

main "$@"