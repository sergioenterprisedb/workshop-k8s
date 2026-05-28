#!/bin/bash

source ./config.sh

# Create namespace
./create_namespace.sh

# Install secretes
print_info "Install secrets\n"
./install_secrets.sh

# Object storage
print_info "\n"
print_info "Object storage\n"
print_command "${kubectl_cmd} apply -f $TMP/object_storage.yaml\n"
${kubectl_cmd} apply -n ${namespace} -f $TMP/object_storage.yaml

# Check object storage
print_info "\n"
print_info "Object storage yaml file here:\n"
print_command "cat $TMP/object_storage.yaml\n"
print_info "\n"

# Create cluster
print_info "Create the Postgres Cluster\n"
print_command "kubectl apply -n ${namespace} -f ${cluster_name}.yaml\n"
${kubectl_cmd} apply -n ${namespace} -f $TMP/${cluster_name}.yaml
