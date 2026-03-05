#!/bin/bash

source ./config.sh

version1=`${kubectl_cnp} version | awk '{ print $2 }' | awk -F":" '{ print $2}'`
version2=${version1%??}
print_command "${kubectl_cmd} apply --server-side  --force-conflicts -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-${version2}/releases/cnpg-${version1}.yaml\n"

${kubectl_cmd} apply --server-side  --force-conflicts -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-${version2}/releases/cnpg-${version1}.yaml

# Wait for the deployment to be available
${kubectl_cmd} wait --for=condition=available deployment/cnpg-controller-manager \
  -n cnpg-system \
  --timeout=120s