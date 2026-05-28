#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# platform/setup/01_system.sh
# Installs system packages and Kubernetes toolchain (Docker, kubectl, helm, k3d, cmctl).
# Prerequisites: Amazon Linux 2023, run as a sudo user (NOT root) for docker group.
# -----------------------------------------------------------------------------
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../config.sh"

install_base_packages() {
  sudo dnf clean all
  sudo dnf -y update

  sudo dnf -y install \
    docker git wget tar gzip unzip \
    bash-completion python3 python3-pip \
    htop vim
}

configure_kernel_limits() {
  # k3s/k3d and a fleet of PostgreSQL pods open many file watchers; the stock
  # inotify limits are too low and surface as "too many open files" at scale.
  sudo tee /etc/sysctl.d/99-workshop.conf >/dev/null <<EOF
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=512
EOF

  sudo sysctl --system
}

configure_docker() {
  # USER may be unbound when running as root via EC2 user-data.
  # Fall back to the current user from the process table.
  local user="${USER:-$(id -un)}"

  sudo systemctl enable --now docker

  # Group membership only takes effect in a fresh login shell; workshop users
  # log in after this step, so no re-login is forced here.
  sudo usermod -aG docker "${user}"
}

install_kubectl() {
  local version
  version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"

  curl -Lo kubectl "https://dl.k8s.io/release/${version}/bin/linux/amd64/kubectl"

  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/kubectl
}

install_helm() {
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}

install_k3d() {
  curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
}

install_cmctl() {
  curl -fsSL -o cmctl https://github.com/cert-manager/cmctl/releases/latest/download/cmctl_linux_amd64

  chmod +x cmctl
  sudo mv cmctl /usr/local/bin/cmctl
}

install_extra_tools() {
  sudo dnf -y install rust cargo

  # `bat` is a convenience pager only; a first-run cargo build can fail on a
  # fresh host (cold crates.io index) without compromising the workshop, so
  # this step is intentionally non-fatal.
  cargo install --locked bat || true

  python3 -m pip install --user rich-cli
}

configure_global_shell() {
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
}

main() {
  # Ensure relative paths resolve correctly regardless of invocation directory.
  cd "$(dirname "${BASH_SOURCE[0]}")"

  install_base_packages
  configure_docker
  configure_kernel_limits
  install_kubectl
  install_helm
  install_k3d
  install_cmctl
  install_extra_tools
  configure_global_shell
}

main "$@"
