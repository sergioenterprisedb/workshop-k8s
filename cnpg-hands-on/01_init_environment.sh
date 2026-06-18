#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# cnpg-hands-on/01_init_environmnet.sh
# -----------------------------------------------------------------------------
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/logger.sh"

show_user_infos() {
    kubectl config set-context --current --namespace="${USER}"
    log_info "Welcome"
    log_info "Your default workspace is set to the namespace ${USER}"
    log_info "Yaml manifests files used in this lab are stored in manifests directory"
    log_info "Follow the step in the order to achieve correctly this lab"
}

main() {
    show_user_infos
}

main "$@"