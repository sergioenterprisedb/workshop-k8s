#!/bin/bash

source ./config.sh

# Create yaml file from template
envsubst < templates/cluster-example-major-upgrade-by-copy.yaml > $TMP/${cluster_name}-major-upgrade-by-copy.yaml

# Show config
print_info "Configuration:\n" 
cat $TMP/${cluster_name}-major-upgrade-by-copy.yaml

# Create cluster
print_command "${kubectl_cmd} apply -n ${namespace} -f $TMP/${cluster_name}-major-upgrade-by-copy.yaml\n"
${kubectl_cmd} apply -n ${namespace} -f $TMP/${cluster_name}-major-upgrade-by-copy.yaml
