#!/bin/bash

# Install AWS EC2 Amazon Linux 2023
sudo dnf -y install docker

# Start and enable docker
sudo systemctl start docker
sudo systemctl enable docker

# Install K3d
sudo dnf -y install wget
wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
k3d --version

sudo usermod -aG docker ec2-user

# Install kubectl
arch=$(uname -m)

[ "$arch" = "x86_64" ] && KUBECTL_ARCH="amd64"
[ "$arch" = "aarch64" ] && KUBECTL_ARCH="arm64"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${KUBECTL_ARCH}/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/bin/kubectl
echo 'source <(kubectl completion bash)' | tee -a ~/.bashrc /home/ec2-user/.bashrc > /dev/null

# Install K3d cluster
./install_k3d.sh

# K3d nodes labels
kubectl label node k3d-workshop-agent-0 datacenter=dc1
kubectl label node k3d-workshop-agent-1 datacenter=dc1
kubectl label node k3d-workshop-agent-2 datacenter=dc1

# Install cmctl
curl -fsSL -o cmctl https://github.com/cert-manager/cmctl/releases/latest/download/cmctl_linux_${KUBECTL_ARCH}
chmod +x cmctl
sudo mv cmctl /usr/local/bin/

# Install htop
sudo dnf install -y htop

# bat install

## 1. Install Rust and Cargo
sudo dnf install -y rust cargo

## 2. Install bat
cargo install --locked bat

## 3. Add Cargo's bin to your PATH (if not already there)
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Install rich
sudo dnf install python3 python3-pip -y
sudo pip3 install rich-cli
rich --version

# Vagrant user profile config
echo "alias k=kubectl" >> /home/ec2-user/.bash_profile
echo 'complete -o default -F __start_kubectl k' >> /home/ec2-user/.bash_profile

# Alias gets
#echo "alias gc='/home/ec2-user/workshop-k8s/admin/get_clusters.sh'" >> /home/${ENV_USER}/.bash_profile
#echo "alias gp='/home/ec2-user/workshop-k8s/admin/get_pods.sh'" >> /home/${ENV_USER}/.bash_profile
#echo "alias gs='/home/ec2-user/workshop-k8s/admin/get_status.sh'" >> /home/${ENV_USER}/.bash_profile
