#!/bin/bash

. ./config.sh

export replica=`kubectl get pod -o=jsonpath="{range .items[*]}{.metadata.name}{'\t'}{.status.podIP}{'\t'}{.metadata.labels.role}{'\n'}" | grep ${cluster_name}- | grep replica | awk '{print $1}' | head -1`

print_info "Standby instance: ${red}${replica}\n"
