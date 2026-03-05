#!/bin/bash

source ./config.sh
source ./replica.sh

print_command "${kubectl_cnp} promote -n ${namespace} ${cluster_name} ${replica}\n"

${kubectl_cnp} promote -n ${namespace} ${cluster_name} ${replica}
