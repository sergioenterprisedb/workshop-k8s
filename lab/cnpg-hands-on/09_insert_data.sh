#!/bin/bash

source ./config.sh

print_info "Contents of SQL file: "
cat sql/create_data.sql


cat sql/create_data.sql | ${kubectl_cnp} psql  ${cluster_name}
