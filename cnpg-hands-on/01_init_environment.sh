#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# cnpg-hands-on/01_init_environmnet.sh
# -----------------------------------------------------------------------------
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/ui.sh"

PUBLIC_IP=$(curl -s https://api.ipify.org)

show_user_infos() {
    ui_section "Welcome to CNPG Hands on lab"
    ui_info "Your default workspace is set to the namespace ${USER}"
    ui_pause
    ui_info "TIPS : If you loose your context, type this command : "
    ui_command "kubectl config set-context --current --namespace=${USER}"
    ui_pause
    ui_info "Yaml manifests files used in this lab are stored in manifests directory :"
    ui_command "ls -al  manifests"
    ui_pause
    ui_info "Follow the step in the order to achieve correctly this lab"
    ui_info "All the resources you create is suffixed by -${USER}"
    ui_success "Access to Grafana : http://${PUBLIC_IP}:3010 (admin/password)"
    ui_success "Access to Minio   : http://${PUBLIC_IP}:9010 (admin/password)"
    ui_pause
    ui_info "K8S cluster is composed of 1 Control plane node and 3 dedicated Postgres worker nodes"
    ui_command "kubectl get nodes --label-columns=node.workshop/role"
}

main() {
    clear 	
    show_user_infos
}

main "$@"
