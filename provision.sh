#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# provision.sh
# Provisions AWS infrastructure and optionally installs the workshop platform.
# Usage: ./provision.sh [--infra-only | --full | --delete | --help]
# -----------------------------------------------------------------------------
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Set the shared session log before sourcing the logger so child scripts inherit it.
export GLOBAL_LOG_FILE="${SCRIPT_DIR}/logs/session_$(date +%Y%m%d_%H%M%S).log"
source "${SCRIPT_DIR}/lib/logger.sh"

show_help() {
  printf 'Usage: ./provision.sh <command> [options]\n\n'
  printf 'Commands:\n'
  printf '  %-15s %s\n' "--infra-only" "Provision AWS infrastructure only (VPC, EC2, EBS volumes)"
  printf '  %-15s %s\n' "--full"       "Provision infrastructure + install platform automatically"
  printf '  %-15s %s\n' ""             "via SSH after infrastructure is ready"
  printf '  %-15s %s\n' "--delete"     "Destroy all AWS resources tagged with TAG_NAME"
  printf '\nOptions:\n'
  printf '  %-15s %s\n' "--help, -h"    "Show this help message"
  printf '\nExamples:\n'
  printf '  %s\n' "./provision.sh --infra-only"
  printf '  %s\n' "./provision.sh --full"
  printf '  %s\n' "./provision.sh --delete"
}

run_infra_only() {
  log_section "Provisioning AWS infrastructure"
  "${SCRIPT_DIR}/infra/create.sh"
  local public_ip
  public_ip=$(cat "${SCRIPT_DIR}/infra/.last_public_ip")
  log_section "Preparing instance"
  provision_instance "${public_ip}"
  log_success "Instance ready — ${public_ip}"
  log_info "SSH : ssh -i ${KEY_PATH} ec2-user@${public_ip}"
  log_info "Next: cd ~/workshop-k8s-cnpg/platform && ./install.sh"
}

run_full() {
  log_section "Provisioning AWS infrastructure"
  "${SCRIPT_DIR}/infra/create.sh"
  local public_ip
  public_ip=$(cat "${SCRIPT_DIR}/infra/.last_public_ip")
  log_section "Preparing instance"
  provision_instance "${public_ip}"
  log_section "Installing platform"
  ssh -i "${KEY_PATH}" \
    -o StrictHostKeyChecking=no \
    "ec2-user@${public_ip}" \
    "bash ~/workshop-k8s-cnpg/platform/install.sh" 2>&1 | log_stream
  log_section "Workshop ready"
  log_success "Provisioning complete"
  log_info "Grafana  : http://${public_ip}:${GRAFANA_PORT}"
  log_info "MinIO    : http://${public_ip}:${MINIO_CONSOLE_PORT}"
  log_info "Terminal : http://${public_ip}:${TTYD_PORT}"
  log_info "SSH      : ssh -i ${KEY_PATH} ec2-user@${public_ip}"
}

run_delete() {
  log_section "Destroying AWS infrastructure"
  # Safety confirmation prompt — the user must retype the tag name.
  printf '\n  Type the tag name to confirm deletion [%s]: ' "${TAG_NAME}"
  read -r confirmation

  if [[ "${confirmation}" != "${TAG_NAME}" ]]; then
    die "Confirmation did not match — aborting"
  fi

  if ! "${SCRIPT_DIR}/infra/delete.sh"; then
    die "Teardown failed"
  fi
  log_success "All resources deleted"
}

provision_instance() {
  local public_ip="$1"
  wait_for_ssh "${public_ip}"
  prepare_instance "${public_ip}"
}

wait_for_ssh() {
  local public_ip="$1"
  local max_attempts="${2:-30}"
  local attempt=0

  log_info "Waiting for SSH on ${public_ip}..."
  until ssh -i "${KEY_PATH}" \
            -o StrictHostKeyChecking=no \
            -o ConnectTimeout=5 \
            -o BatchMode=yes \
            "ec2-user@${public_ip}" "exit" 2>/dev/null; do
    attempt=$(( attempt + 1 ))
    if [[ "${attempt}" -ge "${max_attempts}" ]]; then
      return 1
    fi
    sleep 10
  done
  log_success "SSH available — ${public_ip}"
}

prepare_instance() {
  local public_ip="$1"
  log_section "Installing prerequisites on instance"
  ssh -i "${KEY_PATH}" \
    -o StrictHostKeyChecking=no \
    "ec2-user@${public_ip}" \
    "sudo dnf update -y && \
     sudo dnf install -y git && \
     git clone --branch ${WORKSHOP_REPO_BRANCH} \
       ${WORKSHOP_REPO_URL} ~/workshop-k8s-cnpg" > /dev/null 2>&1 &
  log_spinner $! "Preparing instance"
}

main() {
  init_logger
  case "${COMMAND}" in
    infra-only) run_infra_only ;;
    full)       run_full ;;
    delete)     run_delete ;;
  esac
  finalize_logger
}

COMMAND=""

for arg in "$@"; do
  case "${arg}" in
    --infra-only)  COMMAND="infra-only" ;;
    --full)        COMMAND="full" ;;
    --delete)      COMMAND="delete" ;;
    --help|-h)     show_help; exit 0 ;;
    *)
      echo "Unknown option: ${arg}"
      show_help
      exit 1
      ;;
  esac
done

if [[ -z "${COMMAND}" ]]; then
  show_help
  exit 0
fi

main "$@"
