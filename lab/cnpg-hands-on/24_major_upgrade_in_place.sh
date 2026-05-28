#!/bin/bash

source ./config.sh

# Create yaml file from template
envsubst < templates/cluster-example-major-upgrade-inplace-template.yaml > $TMP/${cluster_name}-major-upgrade-inplace.yaml

# Diff old vs new config
clear
print_command "diff -a --suppress-common-lines -y $TMP/${cluster-name}-minor-upgrade.yaml $TMP/${cluster_name}-major-upgrade-inplace.yaml\n"
diff -a --suppress-common-lines -y $TMP/${cluster_name}-minor-upgrade.yaml $TMP/${cluster_name}-major-upgrade-inplace.yaml

sleep 5

# Create cluster
print_command "${kubectl_cmd} apply -n ${namespace} -f $TMP/${cluster_name}-major-upgrade-inplace.yaml\n"
${kubectl_cmd} apply -n ${namespace} -f $TMP/${cluster_name}-major-upgrade-inplace.yaml
