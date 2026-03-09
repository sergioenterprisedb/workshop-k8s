#!/bin/bash

if ! command -v rich &> /dev/null; then
  echo "rich not installed"
  exit 1
fi

filter=$1
tempfile=$(mktemp)
echo "Namespace,Name,Instances,Status" > $tempfile

# Using jsonpath to extract CNPG Cluster specifics
if [ -z "$filter" ]; then
  kubectl get clusters.postgresql.cnpg.io -A \
    -o jsonpath="{range .items[*]}{.metadata.namespace},{.metadata.name},{.status.instances},{.status.phase}{'\n'}{end}" >> "$tempfile"
else
  kubectl get clusters.postgresql.cnpg.io -A \
    -o jsonpath="{range .items[*]}{.metadata.namespace},{.metadata.name},{.status.instances},{.status.phase}{'\n'}{end}" | \
    grep -E "$filter" >> "$tempfile"
fi

rich --csv "$tempfile"
rm "$tempfile"
