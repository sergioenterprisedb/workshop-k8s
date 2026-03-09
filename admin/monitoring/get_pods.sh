#!/bin/bash

if ! command -v rich &> /dev/null; then
  echo "rich not installed"
  exit 1
fi

filter=$1
tempfile=$(mktemp)
echo "Namespace,Name,Status,Role,Pod IP,Node" > $tempfile

#kubectl get pods --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.containerStatuses[*].ready,STATUS:.status.phase,IP:.status.podIP,NODE:.spec.nodeName" | \
#  grep -E "NAME|─|━|$filter" >> $tempfile

if [ -z "$filter" ]; then
  kubectl get pods -A \
    -o jsonpath="{range .items[*]}{.metadata.namespace},{.metadata.name},{.status.phase},{.metadata.labels.role},{.status.podIP},{.spec.nodeName}{'\n'}{end}" >> "$tempfile"
else
  kubectl get pods -A \
    -o jsonpath="{range .items[*]}{.metadata.namespace},{.metadata.name},{.status.phase},{.metadata.labels.role},{.status.podIP},{.spec.nodeName}{'\n'}{end}" | \
    grep -E "NAME|─|━|$filter" >> "$tempfile"
fi

rich --csv "$tempfile"
rm $tempfile
