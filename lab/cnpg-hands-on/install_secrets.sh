#!/bin/bash

. ./config.sh

print_info "Create the Object Store Configuration \n"

# Object Storage check

print_info "Create the Minio Secret...\n"

kubectl delete secret -n ${namespace} minio-creds --ignore-not-found

print_command "${kubectl_cmd} create secret -n ${namespace} generic minio-creds\n \
  --from-literal=MINIO_ACCESS_KEY=${ACCESS_KEY_ID}\n \
  --from-literal=MINIO_SECRET_KEY=${ACCESS_SECRET_KEY}\n"

${kubectl_cmd} create secret -n ${namespace} generic minio-creds \
  --from-literal=MINIO_ACCESS_KEY=${ACCESS_KEY_ID} \
  --from-literal=MINIO_SECRET_KEY=${ACCESS_SECRET_KEY}

envsubst < templates/minio-template.yaml > "$TMP/object_storage.yaml"

