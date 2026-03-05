#!/bin/bash

source ./config.sh

print_command "${kubectl_cmd} describe backup ${cluster_name}"-backup-test"\n"
sleep 1
${kubectl_cmd} describe backup ${cluster_name}"-backup-test"
