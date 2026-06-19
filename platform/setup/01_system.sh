#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# platform/setup/01_system.sh
# Installs system packages and Kubernetes toolchain (Docker, kubectl, helm, k3d, cmctl).
# Prerequisites: Amazon Linux 2023, run as a sudo user (NOT root) for docker group.
# -----------------------------------------------------------------------------
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../config.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/logger.sh"

install_base_packages() {
  log_section "Installing base packages"
  sudo dnf clean all >/dev/null 2>&1
  sudo dnf -y update >/dev/null 2>&1

  sudo dnf -y install \
    docker git wget tar gzip unzip \
    bash-completion python3 python3-pip \
    htop vim >/dev/null 2>&1
  log_success "Base packages installed"
}

configure_kernel_limits() {
  log_section "Configuring kernel limits"
  # k3s/k3d and a fleet of PostgreSQL pods open many file watchers; the stock
  # inotify limits are too low and surface as "too many open files" at scale.
  sudo tee /etc/sysctl.d/99-workshop.conf >/dev/null <<EOF
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=512
EOF

  sudo sysctl --system >/dev/null 2>&1
  log_success "Kernel limits applied"
}

configure_docker() {
  log_section "Configuring Docker"
  # USER may be unbound when running as root via EC2 user-data.
  # Fall back to the current user from the process table.
  local user="${USER:-$(id -un)}"

  sudo systemctl enable --now docker >/dev/null 2>&1

  # Group membership only takes effect in a fresh login shell; workshop users
  # log in after this step, so no re-login is forced here.
  sudo usermod -aG docker "${user}"
  log_success "Docker enabled for ${user}"
}

install_kubectl() {
  log_section "Installing kubectl"
  local version
  version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"

  curl -Lo kubectl "https://dl.k8s.io/release/${version}/bin/linux/amd64/kubectl" >/dev/null 2>&1

  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/kubectl
  log_success "kubectl installed"
}

install_helm() {
  log_section "Installing helm"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >/dev/null 2>&1
  log_success "helm installed: $(helm version --short 2>/dev/null)"
}

install_k3d() {
  log_section "Installing k3d"
  curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash >/dev/null 2>&1
  log_success "k3d installed: $(k3d version 2>/dev/null | head -1)"
}

install_cmctl() {
  log_section "Installing cmctl"
  curl -fsSL -o cmctl https://github.com/cert-manager/cmctl/releases/latest/download/cmctl_linux_amd64 >/dev/null 2>&1

  chmod +x cmctl
  sudo mv cmctl /usr/local/bin/cmctl
  log_success "cmctl installed"
}

install_gum() {
  log_section "Installing Gum"

  local version="0.17.0"

  curl -fsSL \
    "https://github.com/charmbracelet/gum/releases/download/v${version}/gum_${version}_Linux_x86_64.tar.gz" \
    | tar -xz -C /tmp

  sudo install -m 755 \
    /tmp/gum_${version}_Linux_x86_64/gum \
    /usr/local/bin/gum

  rm -rf "/tmp/gum_${version}_Linux_x86_64"

  log_success "Gum installed: $(gum --version)"
}

configure_global_shell() {
  log_section "Configuring global shell environment"
  docker completion bash | sudo tee /etc/bash_completion.d/docker >/dev/null
  kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl >/dev/null
  helm completion bash | sudo tee /etc/bash_completion.d/helm >/dev/null
  k3d completion bash | sudo tee /etc/bash_completion.d/k3d >/dev/null

  # Export KUBECONFIG and extend PATH for every login shell so workshop users
  # get a working kubectl / `k` alias with no manual setup.
  sudo tee /etc/profile.d/workshop.sh >/dev/null <<EOF
export KUBECONFIG="\$HOME/.kube/config"
export PATH="\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH"

alias k=kubectl
complete -o default -F __start_kubectl k
EOF
  log_success "Shell environment configured"
}

main() {
  # Ensure relative paths resolve correctly regardless of invocation directory.
  cd "$(dirname "${BASH_SOURCE[0]}")"

  init_logger

  install_base_packages
  configure_docker
  configure_kernel_limits
  install_kubectl
  install_helm
  install_k3d
  install_cmctl
  install_gum
  configure_global_shell

  finalize_logger
}

main "$@"
