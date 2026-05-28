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
export WORKSHOP_REPO_BRANCH="review/rchir"
# On EC2 the workshop is cloned into ec2-user home by user-data.
# Override this value if running as a different user.
export WORKSHOP_HOME="${WORKSHOP_HOME:-/home/ec2-user/workshop-k8s-cnpg}"
export SOURCE_CNP_PATH="${WORKSHOP_HOME}/lab/cnpg-hands-on"
export SOURCE_ADMIN_PATH="${WORKSHOP_HOME}/platform"

# =============================================================================
# WORKSHOP USERS
# =============================================================================
export TOTAL_USERS=10
export WORKSHOP_USER_PREFIX="user"
# SECURITY: change WORKSHOP_USER_PASSWORD_PREFIX before running
# in a real workshop environment.
export WORKSHOP_USER_PASSWORD_PREFIX="password"
export WORKSHOP_LAB_DIR_NAME="cnpg-hands-on"
export WORKSHOP_CONTEXT_SCRIPT="./set_context.sh"

# =============================================================================
# MINIO — Object Storage
# =============================================================================
export MINIO_CONTAINER_NAME="minio"
export MINIO_DATA_DIR="/mnt/backup/minio"
export MINIO_API_PORT="9000"
export MINIO_CONSOLE_PORT="9010"
export MINIO_ROOT_USER="admin"
# SECURITY: change MINIO_ROOT_PASSWORD before running
# in a real workshop environment.
export MINIO_ROOT_PASSWORD="password"
export MINIO_ENDPOINT="http://minio:9000"

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
# LOGGING
# =============================================================================
# The logging mechanism has been removed and is being redesigned.
# Scripts currently print progress directly with echo.
