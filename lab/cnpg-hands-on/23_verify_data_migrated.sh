#!/bin/bash

source ./config.sh

print_command "echo \"select version();\" | ${kubectl_cnp} psql ${cluster_major_upgrade}\n"
print_command "echo \"select * from test;\" | ${kubectl_cnp} psql ${cluster_major_upgrade}\n"

cat sql/verify_data.sql | ${kubectl_cnp} psql ${cluster_major_upgrade}
