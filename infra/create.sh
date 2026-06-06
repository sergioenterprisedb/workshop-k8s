#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# infra/create.sh
# Provisions the AWS infrastructure (key pair, VPC, networking, EC2 + 4 EBS volumes).
# Prerequisites: AWS CLI v2 configured; MY_CIDR set in config.sh.
# Usage: ./create.sh (run from repo root or infra/)
# -----------------------------------------------------------------------------
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../config.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/logger.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

create_key_pair() {
  log_section "SSH key pair"
  mkdir -p "${SSH_DIR}"

  if aws ec2 describe-key-pairs --region "${REGION}" --key-names "${KEY_NAME}" >/dev/null 2>&1; then
    # The private key can only be downloaded at creation time; if AWS holds the
    # key pair but the local .pem is gone, the instance would be unreachable.
    if [ ! -f "${KEY_PATH}" ]; then
      die "Key pair exists in AWS but local key is missing: ${KEY_PATH}"
    fi
    chmod 400 "${KEY_PATH}"
    log_warn "Reusing existing key pair: ${KEY_PATH}"
  else
    # Output IS the private key material, so it is written to KEY_PATH.
    aws ec2 create-key-pair \
      --region "${REGION}" \
      --key-name "${KEY_NAME}" \
      --query "KeyMaterial" \
      --output text > "${KEY_PATH}"
    chmod 400 "${KEY_PATH}"
    log_success "Key pair created: ${KEY_PATH}"
  fi
}

create_vpc() {
  log_section "VPC"
  VPC_ID=$(aws ec2 create-vpc \
    --cidr-block "${VPC_CIDR}" \
    --region "${REGION}" \
    --query "Vpc.VpcId" \
    --output text)

  aws ec2 create-tags --resources "${VPC_ID}" \
    --region "${REGION}" \
    --tags Key=Name,Value="${TAG_NAME}-vpc" >> "${LOG_FILE}" 2>&1

  # DNS support + hostnames are required for the instance to get a public DNS name.
  aws ec2 modify-vpc-attribute --vpc-id "${VPC_ID}" \
    --enable-dns-support "{\"Value\":true}" --region "${REGION}" >> "${LOG_FILE}" 2>&1
  aws ec2 modify-vpc-attribute --vpc-id "${VPC_ID}" \
    --enable-dns-hostnames "{\"Value\":true}" --region "${REGION}" >> "${LOG_FILE}" 2>&1
  log_success "VPC created: ${VPC_ID}"
}

create_internet_gateway() {
  log_section "Internet gateway"
  IGW_ID=$(aws ec2 create-internet-gateway \
    --region "${REGION}" \
    --query "InternetGateway.InternetGatewayId" \
    --output text)

  aws ec2 attach-internet-gateway \
    --internet-gateway-id "${IGW_ID}" \
    --vpc-id "${VPC_ID}" \
    --region "${REGION}" >> "${LOG_FILE}" 2>&1
  log_success "IGW created and attached: ${IGW_ID}"
}

create_subnet() {
  log_section "Subnet"
  SUBNET_ID=$(aws ec2 create-subnet \
    --vpc-id "${VPC_ID}" \
    --cidr-block "${SUBNET_CIDR}" \
    --region "${REGION}" \
    --query "Subnet.SubnetId" \
    --output text)

  # Auto-assign public IPs so the instance is reachable without an Elastic IP.
  aws ec2 modify-subnet-attribute \
    --subnet-id "${SUBNET_ID}" \
    --map-public-ip-on-launch \
    --region "${REGION}" >> "${LOG_FILE}" 2>&1
  log_success "Subnet created: ${SUBNET_ID}"
}

create_route_table() {
  log_section "Route table"
  RT_ID=$(aws ec2 create-route-table \
    --vpc-id "${VPC_ID}" \
    --region "${REGION}" \
    --query "RouteTable.RouteTableId" \
    --output text)

  aws ec2 create-route \
    --route-table-id "${RT_ID}" \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id "${IGW_ID}" \
    --region "${REGION}" >> "${LOG_FILE}" 2>&1

  aws ec2 associate-route-table \
    --route-table-id "${RT_ID}" \
    --subnet-id "${SUBNET_ID}" \
    --region "${REGION}" >> "${LOG_FILE}" 2>&1
  log_success "Route table configured: ${RT_ID}"
}

create_security_group() {
  log_section "Security group"
  SG_ID=$(aws ec2 create-security-group \
    --group-name "${TAG_NAME}-sg" \
    --description "EC2 SG" \
    --vpc-id "${VPC_ID}" \
    --region "${REGION}" \
    --query "GroupId" \
    --output text)

  # SSH is restricted to the admin IP (MY_CIDR) for security.
  # Workshop ports are open to 0.0.0.0/0 — participants connect from anywhere.
  aws ec2 authorize-security-group-ingress \
    --group-id "${SG_ID}" \
    --protocol tcp \
    --port 22 \
    --cidr "${MY_CIDR}" \
    --region "${REGION}" >> "${LOG_FILE}" 2>&1
  log_info "Allowed TCP 22 from ${MY_CIDR}"

  aws ec2 authorize-security-group-ingress \
    --group-id "${SG_ID}" \
    --protocol tcp \
    --port "${GRAFANA_PORT}" \
    --cidr "0.0.0.0/0" \
    --region "${REGION}" >> "${LOG_FILE}" 2>&1
  log_info "Allowed TCP ${GRAFANA_PORT} from 0.0.0.0/0"

  aws ec2 authorize-security-group-ingress \
    --group-id "${SG_ID}" \
    --protocol tcp \
    --port "${MINIO_CONSOLE_PORT}" \
    --cidr "0.0.0.0/0" \
    --region "${REGION}" >> "${LOG_FILE}" 2>&1
  log_info "Allowed TCP ${MINIO_CONSOLE_PORT} from 0.0.0.0/0"

  aws ec2 authorize-security-group-ingress \
    --group-id "${SG_ID}" \
    --protocol tcp \
    --port "${TTYD_PORT}" \
    --cidr "0.0.0.0/0" \
    --region "${REGION}" >> "${LOG_FILE}" 2>&1
  log_info "Allowed TCP ${TTYD_PORT} from 0.0.0.0/0"
  log_success "Security group created: ${SG_ID}"
}

fetch_ami() {
  log_section "AMI"
  AMI_ID=$(aws ec2 describe-images \
    --region "${REGION}" \
    --owners amazon \
    --filters "Name=name,Values=al2023-ami-*-x86_64" \
    --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" \
    --output text)
  log_success "AMI resolved: ${AMI_ID}"
}

launch_instance() {
  log_section "EC2 instance"
  local template USER_DATA
  template="${SCRIPT_DIR}/templates/user-data.sh"

  if [[ ! -f "${template}" ]]; then
    die "User-data template not found: ${template}"
  fi

  # Substitute only the repo placeholders; everything else (loop vars, $(date),
  # ${EC2_WORKSHOP_HOME}, redirections) stays literal for the on-instance shell.
  USER_DATA=$(WORKSHOP_REPO_URL="${WORKSHOP_REPO_URL}" \
              WORKSHOP_REPO_BRANCH="${WORKSHOP_REPO_BRANCH}" \
              envsubst '${WORKSHOP_REPO_URL} ${WORKSHOP_REPO_BRANCH}' \
              < "${template}")

  INSTANCE_ID=$(aws ec2 run-instances \
    --region "${REGION}" \
    --image-id "${AMI_ID}" \
    --instance-type "${INSTANCE_TYPE}" \
    --key-name "${KEY_NAME}" \
    --security-group-ids "${SG_ID}" \
    --subnet-id "${SUBNET_ID}" \
    --associate-public-ip-address \
    --block-device-mappings '[
    {"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":50,"VolumeType":"gp3","Iops":6000,"Throughput":300,"DeleteOnTermination":true}},
    {"DeviceName":"/dev/xvdb","Ebs":{"VolumeSize":50,"VolumeType":"gp3","Iops":6000,"Throughput":300,"DeleteOnTermination":true}},
    {"DeviceName":"/dev/xvdc","Ebs":{"VolumeSize":50,"VolumeType":"gp3","Iops":6000,"Throughput":300,"DeleteOnTermination":true}},
    {"DeviceName":"/dev/xvdd","Ebs":{"VolumeSize":50,"VolumeType":"gp3","Iops":6000,"Throughput":300,"DeleteOnTermination":true}}
  ]' \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG_NAME}]" \
    --user-data "${USER_DATA}" \
    --query "Instances[0].InstanceId" \
    --output text)

  aws ec2 wait instance-running \
    --instance-ids "${INSTANCE_ID}" --region "${REGION}" &
  log_spinner $! "Waiting for instance to be running"

  PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "${INSTANCE_ID}" \
    --region "${REGION}" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)

  # Write the SSH shortcut next to this script so it is always infra/connect_ec2.sh,
  # regardless of the directory the script was launched from.
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "ssh -i ${KEY_PATH} ec2-user@${PUBLIC_IP}" > "${script_dir}/connect_ec2.sh"
  chmod +x "${script_dir}/connect_ec2.sh"
  log_success "Instance ready: ${INSTANCE_ID} — ${PUBLIC_IP}"
}

print_summary() {
  # Record the public IP so provision.sh (full mode) can reach the instance
  # without re-querying AWS.
  echo "${PUBLIC_IP}" > "${SCRIPT_DIR}/.last_public_ip"

  log_section "Infrastructure ready"
  log_info "Public IP : ${PUBLIC_IP}"
  log_info "SSH       : ssh -i ${KEY_PATH} ec2-user@${PUBLIC_IP}"
  log_info "Connect   : ./infra/connect_ec2.sh"
}

main() {
  # Ensure relative paths resolve correctly regardless of invocation directory.
  cd "$(dirname "${BASH_SOURCE[0]}")"

  init_logger

  create_key_pair
  create_vpc
  create_internet_gateway
  create_subnet
  create_route_table
  create_security_group
  fetch_ami
  launch_instance
  print_summary

  finalize_logger
}

main "$@"
