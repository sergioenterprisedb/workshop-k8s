#!/bin/bash
# -----------------------------------------------------------------------------
# platform/scripts/get_pvc.sh
# Prints PersistentVolumeClaims across all namespaces as a rich table (optional filter).
# -----------------------------------------------------------------------------
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../config.sh"

# Ensure relative paths resolve correctly regardless of invocation directory.
cd "$(dirname "${BASH_SOURCE[0]}")"

if ! command -v rich &> /dev/null; then
  echo "rich not installed"
  exit 1
fi

# Default to empty so an absent argument does not trip `set -u` from config.sh.
filter="${1:-}"
tempfile=$(mktemp)
echo "Namespace,Name,Status,StorageClass,Size,AccessMode" > $tempfile

# Targeting PVC resources across all namespaces
if [ -z "$filter" ]; then
  kubectl get pvc -A \
    -o jsonpath="{range .items[*]}{.metadata.namespace},{.metadata.name},{.status.phase},{.spec.storageClassName},{.status.capacity.storage},{.spec.accessModes[0]}{'\n'}{end}" >> "$tempfile"
else
  kubectl get pvc -A \
    -o jsonpath="{range .items[*]}{.metadata.namespace},{.metadata.name},{.status.phase},{.spec.storageClassName},{.status.capacity.storage},{.spec.accessModes[0]}{'\n'}{end}" | \
    grep -E "NAME|─|━|$filter" >> "$tempfile" || true
fi

rich --csv "$tempfile"
rm "$tempfile"
