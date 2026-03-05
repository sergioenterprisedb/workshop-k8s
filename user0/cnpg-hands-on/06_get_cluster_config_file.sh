#!/bin/bash

source ./config.sh

envsubst < templates/${cluster_name_template}-template.yaml > $TMP/${cluster_name}.yaml

echo ""
print_info "Please, run this command:\n"
print_command "cat $TMP/${cluster_name}.yaml\n"
echo ""

