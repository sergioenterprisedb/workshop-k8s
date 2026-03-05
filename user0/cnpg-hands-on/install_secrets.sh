#!/bin/bash

. ./config.sh

print_info "Create the Object Store Configuration \n"

# Object Storage check
if [ "$object_storage_type" = "minio" ]; then

  print_info "Create the Minio Secret...\n"

  kubectl delete secret -n ${namespace} minio-creds --ignore-not-found

  print_command "${kubectl_cmd} create secret -n ${namespace} generic minio-creds\n \
    --from-literal=MINIO_ACCESS_KEY=${ACCESS_KEY_ID}\n \
    --from-literal=MINIO_SECRET_KEY=${ACCESS_SECRET_KEY}\n"

  ${kubectl_cmd} create secret -n ${namespace} generic minio-creds \
    --from-literal=MINIO_ACCESS_KEY=${ACCESS_KEY_ID} \
    --from-literal=MINIO_SECRET_KEY=${ACCESS_SECRET_KEY}

  envsubst < templates/minio-template.yaml > "$TMP/object_storage.yaml"

elif [ "$object_storage_type" = "aws" ]; then

  print_info "Create the AWS Secret...\n"
  
  kubectl delete secret aws-creds --ignore-not-found

  print_info "  kubectl create secret generic aws-creds\n \
    --from-literal=ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}\n \
    --from-literal=ACCESS_SECRET_KEY=${AWS_SECRET_ACCESS_KEY}\n \
    --from-literal=ACCESS_SESSION_TOKEN=${AWS_SESSION_TOKEN}\n"

  ${kubectl_cmd} create secret generic aws-creds \
    --from-literal=ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
    --from-literal=ACCESS_SECRET_KEY="$AWS_SECRET_ACCESS_KEY" \
    --from-literal=ACCESS_SESSION_TOKEN="$AWS_SESSION_TOKEN"

  envsubst < templates/aws-template.yaml > $TMP/object_storage.yaml

elif [ "$object_storage_type" = "azure" ]; then

  print_info "Create the Azure Secret...\n"

  kubectl delete secret azure-creds --ignore-not-found

  export s3_bucket="${s3_bucket}"

  export AZURE_STORAGE_ACCOUNT="${AZURE_STORAGE_ACCOUNT}"
  export AZURE_STORAGE_KEY="${AZURE_STORAGE_KEY}"
  export AZURE_STORAGE_SAS_TOKEN="${AZURE_STORAGE_SAS_TOKEN}"
  export AZURE_CONNECTION_STRING="${AZURE_CONNECTION_STRING}"

  print_info "kubectl create secret generic azure-creds ...\n"
  
  ${kubectl_cmd} create secret generic azure-creds \
    --from-literal=AZURE_STORAGE_ACCOUNT=${AZURE_STORAGE_ACCOUNT} \
    --from-literal=AZURE_STORAGE_KEY=${AZURE_STORAGE_KEY} \
    --from-literal=AZURE_STORAGE_SAS_TOKEN=${AZURE_STORAGE_SAS_TOKEN} \
    --from-literal=AZURE_CONNECTION_STRING=${AZURE_CONNECTION_STRING}

  envsubst < templates/azure-template.yaml > $TMP/object_storage.yaml

fi
