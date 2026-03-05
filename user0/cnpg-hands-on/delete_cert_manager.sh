#!/bin/bash

. ./config.sh

${kubectl_cmd} delete -f https://github.com/cert-manager/cert-manager/releases/download/${cert_manager_version}/cert-manager.yaml

# Optional
${kubectl_cmd} get namespace cert-manager -o json \
| jq '.spec.finalizers=[]' \
| kubectl replace --raw "/api/v1/namespaces/cert-manager/finalize" -f -

${kubectl_cmd} delete crd \
certificates.cert-manager.io \
certificaterequests.cert-manager.io \
challenges.acme.cert-manager.io \
clusterissuers.cert-manager.io \
issuers.cert-manager.io \
orders.acme.cert-manager.io

${kubectl_cmd} delete namespace cert-manager
