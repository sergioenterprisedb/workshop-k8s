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
# AWS INFRASTRUCTURE
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
export WORKSHOP_REPO_BRANCH="feature/logger"
# On EC2 the workshop is cloned into ec2-user home by user-data.
# Override this value if running as a different user.
export WORKSHOP_HOME="${WORKSHOP_HOME:-/home/ec2-user/workshop-k8s-cnpg}"

# =============================================================================
# MINIO — Object Storage
# =============================================================================
export MINIO_CONSOLE_PORT="9010"
export MINIO_ROOT_USER="admin"
# SECURITY: change MINIO_ROOT_PASSWORD before running
# in a real workshop environment.
export MINIO_ROOT_PASSWORD="password"

# =============================================================================
# GRAFANA — Monitoring
# =============================================================================
export GRAFANA_PORT="3010"
export GRAFANA_ADMIN_USER="admin"
# SECURITY: change GRAFANA_ADMIN_PASSWORD before running
# in a real workshop environment.
export GRAFANA_ADMIN_PASSWORD="password"

# =============================================================================
# WEB TERMINAL
# =============================================================================
export TTYD_PORT="4200"

# =============================================================================
# WORKSHOP USERS
# =============================================================================
export TOTAL_USERS=10
export WORKSHOP_USER_PREFIX="user"
# SECURITY: change WORKSHOP_USER_PASSWORD_PREFIX before running
# in a real workshop environment.
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

# Minio Object Storage environment
export BUCKET="demo"
export ACCESS_KEY_ID="admin"
export ACCESS_SECRET_KEY="password"
export OBJECT_STORAGE_BUCKET="${BUCKET}"
export S3_DESTINATION_PATH="s3://${BUCKET}/"
export S3_ENDPOINT_URL="http://minio.minio.svc.cluster.local:9000"