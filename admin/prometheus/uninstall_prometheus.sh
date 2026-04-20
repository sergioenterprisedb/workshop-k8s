#!/bin/bash

. ../config.sh
. ../../user0/cnpg-hands-on/commands.sh


# Uninstall prometheus
print_info "\nUninstalling prometheus...\n"
kubectl get crd
kubectl delete crd prometheuses.monitoring.coreos.com
kubectl delete crd prometheusagents.monitoring.coreos.com
kubectl delete crd prometheusrules.monitoring.coreos.com
kubectl get crd

print_info "\nUninstalling Grafana service...\n"
kubectl delete -f grafana.yaml

# Uninstall prometheus
kubectl delete deployments.apps -n default prometheus-community-grafana 
kubectl delete deployments.apps -n default prometheus-community-kube-operator 
kubectl delete deployments.apps -n default prometheus-community-kube-state-metrics 

