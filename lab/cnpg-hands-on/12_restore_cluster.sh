#!/bin/bash

source ./config.sh

# Doc
echo 12 > ./docs/docid

# Restore
print_command "Displaying the restore.yaml file...\n"
envsubst < templates/restore-template.yaml > $TMP/restore.yaml
#cat $TMP/restore.yaml
#sleep 5

print_command "echo \"select pg_switch_wal()\" | ${kubectl_cnp} psql ${cluster_name}\n"
print_command "kubectl apply -f $TMP/restore.yaml\n"

${kubectl_cmd} apply -f $TMP/restore.yaml
