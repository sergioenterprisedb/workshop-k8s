#!/bin/bash

source ./config.sh

#Doc
echo "10" > ./docs/docid

# Delete backup file
print_command "${kubectl_cmd} delete -f ./yaml/backup.yaml\n"
${kubectl_cmd} delete -f $TMP/backup.yaml > /dev/null 2>&1 

# Generate backup file
envsubst < templates/backup-template.yaml > $TMP/backup.yaml

# Print backup yaml file
print_info "Displaying the backup.yaml file...\n"
cat $TMP/backup.yaml

# Switch wal
print_command "echo \"select pg_switch_wal()\" | ${kubectl_cnp} psql ${cluster_name} -- -U postgres\n"
echo "select pg_switch_wal()" | ${kubectl_cnp} psql ${cluster_name} -- -U postgres
sleep 5

# Backup
print_command "${kubectl_cmd} apply -f $TMP/backup.yaml\n"
${kubectl_cmd} apply -f $TMP/backup.yaml

