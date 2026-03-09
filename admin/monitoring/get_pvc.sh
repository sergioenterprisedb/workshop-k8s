#!/bin/bash

if ! command -v rich &> /dev/null; then
  echo "rich not installed"
  exit 1
fi

filter=$1
tempfile=$(mktemp)
echo "Namespace,Name,Status,StorageClass,Size,AccessMode" > $tempfile

# Targeting PVC resources across all namespaces
if [ -z "$filter" ]; then
  kubectl get pvc -A \
    -o jsonpath="{range .items[*]}{.metadata.namespace},{.metadata.name},{.status.phase},{.spec.storageClassName},{.status.capacity.storage},{.spec.accessModes[0]}{'\n'}{end}" >> "$tempfile"
else
  kubectl get pvc -A \
    -o jsonpath="{range .items[*]}{.metadata.namespace},{.metadata.name},{.status.phase},{.spec.storageClassName},{.status.capacity.storage},{.spec.accessModes[0]}{'\n'}{end}" | \
    grep -E "NAME|─|━|$filter" >> "$tempfile"
fi

rich --csv "$tempfile"
rm "$tempfile"
