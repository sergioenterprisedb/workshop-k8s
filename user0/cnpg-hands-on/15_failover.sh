#!/bin/bash

source ./config.sh
source ./primary.sh

print_command "${yellow}Deleting pvc and pod from primary instance ${primary}...\n"

print_command "${kubectl_cmd} delete -n ${namespace} pvc/${primary} pod/${primary} pvc/${primary}-tbs-idxtbs pvc/${primary}-tbs-tmptbs pvc/${primary}-wal --force\n"

${kubectl_cmd} delete -n ${namespace} pvc/${primary} pod/${primary} pvc/${primary}-tbs-idxtbs pvc/${primary}-tbs-tmptbs pvc/${primary}-wal --force
