#!/bin/bash

. ./config.sh

# Install K3d cluster
#sg docker -c "k3d cluster create ${K3D_CLUSTER}"
#sg docker -c "k3d node create dc1-node1 -c ${K3D_CLUSTER}
#sg docker -c "k3d node create dc1-node2 -c ${K3D_CLUSTER}"
#sg docker -c "k3d node create dc1-node3 -c ${K3D_CLUSTER}"


sg docker -c "k3d cluster create ${K3D_CLUSTER} \
  --servers 1 \
  --agents 3 \
  -v '/:/var/lib/rancher/k3s/storage@server:0' \
  -v '/mnt/disk1:/var/lib/rancher/k3s/storage@agent:0' \
  -v '/mnt/disk2:/var/lib/rancher/k3s/storage@agent:1' \
  -v '/mnt/disk3:/var/lib/rancher/k3s/storage@agent:2'"

# 1. Create a local kubeconfig directory if it doesn't exist
mkdir -p ~/.kube
sg docker -c "k3d kubeconfig get ${K3D_CLUSTER}" > ~/.kube/config
export KUBECONFIG=~/.kube/config
kubectl cluster-info

docker exec -it k3d-workshop-agent-0 df -h | grep storage
docker exec -it k3d-workshop-agent-1 df -h | grep storage
docker exec -it k3d-workshop-agent-2 df -h | grep storage

kubectl label node k3d-workshop-agent-0 role=postgres-node
kubectl label node k3d-workshop-agent-1 role=postgres-node
kubectl label node k3d-workshop-agent-2 role=postgres-node

# Ports
#sg docker -c "k3d cluster edit workshop --port-add '9001:9001@loadbalancer'"
#sg docker -c "k3d cluster edit workshop --port-add '9000:9000@loadbalancer'"
#Minio
#sg docker -c "k3d cluster edit workshop --port-add '9090:9090@loadbalancer'"
# create minio Load Balancer
sg docker -c "k3d cluster edit workshop --port-add '9010:9010@loadbalancer'"
# Grafana
sg docker -c "k3d cluster edit workshop --port-add '3010:3010@loadbalancer'"

# Check open ports
docker ps --filter "name=serverlb" --format "table {{.Names}}\t{{.Ports}}"

# Share k8s config file
sudo mkdir -p /usr/local/share/k8s
sudo chmod 755 /usr/local/share/k8s
sg docker -c "k3d kubeconfig get ${K3D_CLUSTER} | sudo tee /usr/local/share/k8s/k3d-config > /dev/null"
sudo chmod 644 /usr/local/share/k8s/k3d-config
