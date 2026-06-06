#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# infra/delete.sh
# Destroys all AWS resources tagged with TAG_NAME. Irreversible — EBS data is lost.
# Prerequisites: AWS CLI v2 configured.
# Usage: ./delete.sh (run from repo root or infra/)
# -----------------------------------------------------------------------------
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../config.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/logger.sh"

terminate_instance() {
  log_section "Terminating EC2 instance"
  INSTANCE_ID=$(aws ec2 describe-instances \
    --region "${REGION}" \
    --filters "Name=tag:Name,Values=${TAG_NAME}" \
              "Name=instance-state-name,Values=running,stopped,pending" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

  if [[ -z "${INSTANCE_ID:-}" ]]; then
    log_warn "No instance found, skipping"
    return 0
  fi

  # INSTANCE_ID is intentionally unquoted: there may be more than one match.
  aws ec2 terminate-instances --instance-ids ${INSTANCE_ID} --region "${REGION}" >/dev/null 2>&1

  aws ec2 wait instance-terminated \
    --instance-ids ${INSTANCE_ID} --region "${REGION}" &
  log_spinner $! "Waiting for instance termination"
  log_success "Instance terminated: ${INSTANCE_ID}"
}

find_vpc() {
  log_section "Looking up VPC"
  VPC_ID=$(aws ec2 describe-vpcs \
    --region "${REGION}" \
    --filters "Name=tag:Name,Values=${TAG_NAME}-vpc" \
    --query "Vpcs[0].VpcId" \
    --output text)

  if [[ "${VPC_ID}" == "None" || -z "${VPC_ID:-}" ]]; then
    log_warn "No VPC found, nothing to delete"
    exit 0
  fi
  log_success "VPC found: ${VPC_ID}"
}

delete_security_groups() {
  log_section "Deleting security groups"
  local sg_ids sg
  sg_ids=$(aws ec2 describe-security-groups \
    --region "${REGION}" \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query "SecurityGroups[?GroupName!='default'].GroupId" \
    --output text)

  if [[ -z "${sg_ids:-}" ]]; then
    log_warn "No security groups found, skipping"
    return 0
  fi

  for sg in ${sg_ids}; do
    log_info "Deleting ${sg}"
    aws ec2 delete-security-group --group-id "${sg}" --region "${REGION}" >/dev/null 2>&1 || true
  done
  log_success "Security groups deleted"
}

delete_route_tables() {
  log_section "Deleting route tables"
  local rt_ids rt main assoc_ids a
  rt_ids=$(aws ec2 describe-route-tables \
    --region "${REGION}" \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query "RouteTables[].RouteTableId" \
    --output text)

  for rt in ${rt_ids}; do
    [[ -z "${rt}" ]] && continue

    # The main route table cannot be deleted; it is removed with the VPC.
    main=$(aws ec2 describe-route-tables \
      --route-table-ids "${rt}" \
      --region "${REGION}" \
      --query "RouteTables[0].Associations[?Main==\`true\`]" \
      --output text)
    if [[ -n "${main}" ]]; then
      log_debug "Skipping main route table: ${rt}"
      continue
    fi

    assoc_ids=$(aws ec2 describe-route-tables \
      --route-table-ids "${rt}" \
      --region "${REGION}" \
      --query "RouteTables[0].Associations[].RouteTableAssociationId" \
      --output text)

    for a in ${assoc_ids}; do
      [[ "${a}" == "None" || -z "${a}" ]] && continue
      aws ec2 disassociate-route-table --association-id "${a}" --region "${REGION}" >/dev/null 2>&1 || true
    done

    aws ec2 delete-route-table --route-table-id "${rt}" --region "${REGION}" >/dev/null 2>&1 || true
  done
  log_success "Route tables deleted"
}

delete_internet_gateway() {
  log_section "Deleting internet gateway"
  IGW_ID=$(aws ec2 describe-internet-gateways \
    --region "${REGION}" \
    --filters "Name=attachment.vpc-id,Values=${VPC_ID}" \
    --query "InternetGateways[0].InternetGatewayId" \
    --output text)

  if [[ "${IGW_ID}" == "None" || -z "${IGW_ID:-}" ]]; then
    log_warn "No internet gateway found, skipping"
    return 0
  fi

  aws ec2 detach-internet-gateway \
    --internet-gateway-id "${IGW_ID}" \
    --vpc-id "${VPC_ID}" \
    --region "${REGION}" >/dev/null 2>&1
  aws ec2 delete-internet-gateway \
    --internet-gateway-id "${IGW_ID}" \
    --region "${REGION}" >/dev/null 2>&1
  log_success "Internet gateway deleted: ${IGW_ID}"
}

delete_subnets() {
  log_section "Deleting subnets"
  local subnet_ids subnet
  subnet_ids=$(aws ec2 describe-subnets \
    --region "${REGION}" \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query "Subnets[].SubnetId" \
    --output text)

  for subnet in ${subnet_ids}; do
    aws ec2 delete-subnet --subnet-id "${subnet}" --region "${REGION}" >/dev/null 2>&1 || true
  done
  log_success "Subnets deleted"
}

delete_vpc() {
  log_section "Deleting VPC"
  aws ec2 delete-vpc --vpc-id "${VPC_ID}" --region "${REGION}" >/dev/null 2>&1
  log_success "VPC deleted: ${VPC_ID}"
}

delete_key_pair() {
  log_section "Deleting key pair"
  if aws ec2 describe-key-pairs --region "${REGION}" --key-names "${KEY_NAME}" >/dev/null 2>&1; then
    aws ec2 delete-key-pair --region "${REGION}" --key-name "${KEY_NAME}" >/dev/null 2>&1
    log_info "AWS key pair deleted: ${KEY_NAME}"
  fi

  if [[ -f "${KEY_PATH}" ]]; then
    rm -f "${KEY_PATH}"
    log_info "Local key deleted: ${KEY_PATH}"
  fi
  log_success "Key pair deleted"
}

cleanup_local_files() {
  log_section "Cleaning up local files"
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  rm -f "${script_dir}/connect_ec2.sh"
  log_success "Local files cleaned"
}

main() {
  # Ensure relative paths resolve correctly regardless of invocation directory.
  cd "$(dirname "${BASH_SOURCE[0]}")"

  init_logger

  terminate_instance
  find_vpc
  delete_security_groups
  delete_route_tables
  delete_internet_gateway
  delete_subnets
  delete_vpc
  delete_key_pair
  cleanup_local_files

  finalize_logger
}

main "$@"
