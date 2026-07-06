#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# config.sh
#
# Single source of truth for the entire workshop provisioning pipeline.
# Covers infrastructure (AWS/EC2) and platform (k3d, tools, users) settings.
#
# Usage: sourced by all scripts — never executed directly.
#        infra/ scripts   : source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../config.sh"
#        platform/ scripts: source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../config.sh"
# -----------------------------------------------------------------------------

set -Eeuo pipefail

# Ensure HOME is defined — it may be unbound when executed as root
# via EC2 user-data or non-login shells.
HOME="${HOME:-/root}"

# =============================================================================
# AWS INFRASTRUCTURE ex: 
# For 15 users in a workshop : c6i.8xlarge is enough (16 cores / 64 GB / good IOPS)
# For testing environment : t2.2xlarge (8 cores / 32 GB / medium IOPS)
# =============================================================================
export REGION="eu-west-3"
export INSTANCE_TYPE="t2.2xlarge"
export TAG_NAME="rch-rev"

# =============================================================================
# SSH ACCESS
# =============================================================================
export KEY_NAME="rch-k8s-workshop"
export SSH_DIR="${HOME}/.ssh"
export KEY_PATH="${SSH_DIR}/${KEY_NAME}.pem"
# SECURITY: restrict to your own IP address (x.x.x.x/32)
export MY_CIDR="163.0.0.0/8"

# =============================================================================
# NETWORK
# =============================================================================
export VPC_CIDR="10.0.0.0/16"
export SUBNET_CIDR="10.0.1.0/24"

# =============================================================================
# REPOSITORY
# =============================================================================
export WORKSHOP_REPO_URL="https://github.com/sergioenterprisedb/workshop-k8s-cnpg.git"
# Important : to be changed for test branches, could be automate. 
export WORKSHOP_REPO_BRANCH="review/rchir"
# On EC2 the workshop is cloned into ec2-user home by user-data.
export WORKSHOP_HOME="${WORKSHOP_HOME:-/home/ec2-user/workshop-k8s-cnpg}"

# =============================================================================
# MINIO — Object Storage
# =============================================================================
export MINIO_CONSOLE_PORT="9010"
export MINIO_ROOT_USER="admin"
# SECURITY: change MINIO_ROOT_PASSWORD before running
# in a real workshop environment.
export MINIO_ROOT_PASSWORD="password"

# Minio Object Storage environment
export OBJECT_STORAGE_BUCKET="cnpg"
export S3_DESTINATION_PATH="s3://${OBJECT_STORAGE_BUCKET}/"
export S3_ENDPOINT_URL="http://minio.object-storage.svc.cluster.local:9000"

# =============================================================================
# GRAFANA — Monitoring
# =============================================================================
export GRAFANA_PORT="3010"
export GRAFANA_ADMIN_USER="admin"
export GRAFANA_ADMIN_PASSWORD="password"

# =============================================================================
# WEB TERMINAL
# =============================================================================
export TTYD_PORT="4200"

# =============================================================================
# WORKSHOP USERS
# =============================================================================
export TOTAL_USERS=15
export WORKSHOP_USER_PREFIX="user"
export WORKSHOP_USER_PASSWORD_PREFIX="password"

# CNPG cluster parameters
# Sizing
export POSTGRES_INSTANCES=3
export POSTGRES_CPU="0.5"
export POSTGRES_MAX_CPU="0.5"
export POSTGRES_MEMORY="512Mi"
export POSTGRES_MAX_MEMORY="512Mi"

# Storage
export POSTGRES_STORAGE="512Mi"
export POSTGRES_WAL_STORAGE="512Mi"
export POSTGRES_IDX_STORAGE="512Mi"
export POSTGRES_TMP_STORAGE="512Mi"

# Images
export POSTGRES_DEFAULT_IMAGE="quay.io/enterprisedb/postgresql:16.4"
export POSTGRES_MINOR_UPGRADE_IMAGE="quay.io/enterprisedb/postgresql:16.5"
export POSTGRES_MAJOR_UPGRADE_IMAGE="quay.io/enterprisedb/postgresql:17"