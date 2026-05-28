#!/bin/bash

source ./config.sh

envsubst < templates/${cluster_name_template}-minor-upgrade-template.yaml > $TMP/${cluster_name}-minor-upgrade.yaml

clear

# Diff old vs new config
print_info "diff -a --suppress-common-lines -y yaml/${cluster_name}.yaml $TMP/${cluster_name}-minor-upgrade.yaml\n"
diff -a --suppress-common-lines -y $TMP/${cluster_name}.yaml $TMP/${cluster_name}-minor-upgrade.yaml

sleep 2

# Apply minor upgrade
print_info  "Upgrading the Postgres Cluster...\n"
print_command "${kubectl_cmd} apply -f $TMP/${cluster_name}-minor-upgrade.yaml\n"
${kubectl_cmd} apply -n ${namespace} -f $TMP/${cluster_name}-minor-upgrade.yaml
