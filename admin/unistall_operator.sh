#!/bin/bash

version1=`kubectl-cnpg version | awk '{ print $2 }' | awk -F":" '{ print $2}'`
version2=${version1%??}

# Uninstall operator
kubectl delete -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-${version2}/releases/cnpg-${version1}.yaml

