#!/bin/bash
# -----------------------------------------------------------------------------
# platform/scripts/get_clusters.sh
# Prints CNPG clusters across all namespaces as a rich table (optional name filter).
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
echo "Namespace,Name,Instances,Status" > $tempfile

# Using jsonpath to extract CNPG Cluster specifics
if [ -z "$filter" ]; then
  kubectl get clusters.postgresql.cnpg.io -A \
    -o jsonpath="{range .items[*]}{.metadata.namespace},{.metadata.name},{.status.instances},{.status.phase}{'\n'}{end}" >> "$tempfile"
else
  kubectl get clusters.postgresql.cnpg.io -A \
    -o jsonpath="{range .items[*]}{.metadata.namespace},{.metadata.name},{.status.instances},{.status.phase}{'\n'}{end}" | \
    grep -E "$filter" >> "$tempfile" || true
fi

rich --csv "$tempfile"
rm "$tempfile"
