#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# infra/delete.sh
# Destroys all AWS resources tagged with TAG_NAME. Irreversible — EBS data is lost.
# Prerequisites: AWS CLI v2 configured.
# Usage: ./delete.sh (run from repo root or infra/)
# -----------------------------------------------------------------------------
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../config.sh"

terminate_instance() {
  INSTANCE_ID=$(aws ec2 describe-instances \
    --region "${REGION}" \
    --filters "Name=tag:Name,Values=${TAG_NAME}" \
              "Name=instance-state-name,Values=running,stopped,pending" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

  if [[ -z "${INSTANCE_ID:-}" ]]; then
    return 0
  fi

  # INSTANCE_ID is intentionally unquoted: there may be more than one match.
  aws ec2 terminate-instances --instance-ids ${INSTANCE_ID} --region "${REGION}"

  aws ec2 wait instance-terminated --instance-ids ${INSTANCE_ID} --region "${REGION}"
}

find_vpc() {
  VPC_ID=$(aws ec2 describe-vpcs \
    --region "${REGION}" \
    --filters "Name=tag:Name,Values=${TAG_NAME}-vpc" \
    --query "Vpcs[0].VpcId" \
    --output text)

  if [[ "${VPC_ID}" == "None" || -z "${VPC_ID:-}" ]]; then
    exit 0
  fi
}

delete_security_groups() {
  local sg_ids sg
  sg_ids=$(aws ec2 describe-security-groups \
    --region "${REGION}" \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query "SecurityGroups[?GroupName!='default'].GroupId" \
    --output text)

  if [[ -z "${sg_ids:-}" ]]; then
    return 0
  fi

  for sg in ${sg_ids}; do
    aws ec2 delete-security-group --group-id "${sg}" --region "${REGION}" || true
  done
}

delete_route_tables() {
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
      continue
    fi

    assoc_ids=$(aws ec2 describe-route-tables \
      --route-table-ids "${rt}" \
      --region "${REGION}" \
      --query "RouteTables[0].Associations[].RouteTableAssociationId" \
      --output text)

    for a in ${assoc_ids}; do
      [[ "${a}" == "None" || -z "${a}" ]] && continue
      aws ec2 disassociate-route-table --association-id "${a}" --region "${REGION}" || true
    done

    aws ec2 delete-route-table --route-table-id "${rt}" --region "${REGION}" || true
  done
}

delete_internet_gateway() {
  IGW_ID=$(aws ec2 describe-internet-gateways \
    --region "${REGION}" \
    --filters "Name=attachment.vpc-id,Values=${VPC_ID}" \
    --query "InternetGateways[0].InternetGatewayId" \
    --output text)

  if [[ "${IGW_ID}" == "None" || -z "${IGW_ID:-}" ]]; then
    return 0
  fi

  aws ec2 detach-internet-gateway \
    --internet-gateway-id "${IGW_ID}" \
    --vpc-id "${VPC_ID}" \
    --region "${REGION}"
  aws ec2 delete-internet-gateway \
    --internet-gateway-id "${IGW_ID}" \
    --region "${REGION}"
}

delete_subnets() {
  local subnet_ids subnet
  subnet_ids=$(aws ec2 describe-subnets \
    --region "${REGION}" \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query "Subnets[].SubnetId" \
    --output text)

  for subnet in ${subnet_ids}; do
    aws ec2 delete-subnet --subnet-id "${subnet}" --region "${REGION}" || true
  done
}

delete_vpc() {
  aws ec2 delete-vpc --vpc-id "${VPC_ID}" --region "${REGION}"
}

delete_key_pair() {
  if aws ec2 describe-key-pairs --region "${REGION}" --key-names "${KEY_NAME}" >/dev/null 2>&1; then
    aws ec2 delete-key-pair --region "${REGION}" --key-name "${KEY_NAME}"
  fi

  if [[ -f "${KEY_PATH}" ]]; then
    rm -f "${KEY_PATH}"
  fi
}

cleanup_local_files() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  rm -f "${script_dir}/connect_ec2.sh"
}

main() {
  # Ensure relative paths resolve correctly regardless of invocation directory.
  cd "$(dirname "${BASH_SOURCE[0]}")"

  terminate_instance
  find_vpc
  delete_security_groups
  delete_route_tables
  delete_internet_gateway
  delete_subnets
  delete_vpc
  delete_key_pair
  cleanup_local_files
}

main "$@"
