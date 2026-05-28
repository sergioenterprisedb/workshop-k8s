#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# provision.sh
# Provisions AWS infrastructure and optionally installs the workshop platform.
# Usage: ./provision.sh [--infra-only | --full | --delete | --help]
# -----------------------------------------------------------------------------
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

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
  "${SCRIPT_DIR}/infra/create.sh"
  local public_ip
  public_ip=$(cat "${SCRIPT_DIR}/infra/.last_public_ip")
  provision_instance "${public_ip}"
  echo "Ready — ssh -i ${KEY_PATH} ec2-user@${public_ip}"
  echo "Next  — cd ~/workshop-k8s-cnpg/platform && ./install.sh"
}

run_full() {
  "${SCRIPT_DIR}/infra/create.sh"
  local public_ip
  public_ip=$(cat "${SCRIPT_DIR}/infra/.last_public_ip")
  provision_instance "${public_ip}"
  ssh -i "${KEY_PATH}" \
    -o StrictHostKeyChecking=no \
    "ec2-user@${public_ip}" \
    "bash ~/workshop-k8s-cnpg/platform/install.sh"
}

run_delete() {
  # Safety confirmation prompt — the user must retype the tag name.
  printf '\n  Type the tag name to confirm deletion [%s]: ' "${TAG_NAME}"
  read -r confirmation

  if [[ "${confirmation}" != "${TAG_NAME}" ]]; then
    exit 1
  fi

  if ! "${SCRIPT_DIR}/infra/delete.sh"; then
    exit 1
  fi
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
}

prepare_instance() {
  local public_ip="$1"
  ssh -i "${KEY_PATH}" \
    -o StrictHostKeyChecking=no \
    "ec2-user@${public_ip}" \
    "sudo dnf update -y && \
     sudo dnf install -y git && \
     git clone --branch ${WORKSHOP_REPO_BRANCH} ${WORKSHOP_REPO_URL} ~/workshop-k8s-cnpg"
}

main() {
  case "${COMMAND}" in
    infra-only) run_infra_only ;;
    full)       run_full ;;
    delete)     run_delete ;;
  esac
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
