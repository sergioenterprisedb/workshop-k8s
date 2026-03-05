#!/bin/bash

. ./config.sh

#Create namespace
if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
  print_info "Namespace $namespace not found. Creating it...\n"
  print_command "${kubectl_cmd} create namespace '$namespace'"
  ${kubectl_cmd} create namespace "$namespace"
else
  print_info "Namespace $namespace already exists. Skipping.\n"
fi
