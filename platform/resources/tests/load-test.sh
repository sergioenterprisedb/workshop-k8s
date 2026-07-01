#!/usr/bin/env bash
set -Eeuo pipefail

TOTAL_USERS="${TOTAL_USERS:-15}"
INTERVAL=5

RESULT_FILE="load-test-$(date +%Y%m%d-%H%M%S).csv"
MONITOR_PID=""

monitor() {

    echo "timestamp,cpu_percent,memory_percent,load,pods,clusters" > "${RESULT_FILE}"

    while true; do
        timestamp=$(date +"%F %T")
        cpu=$(top -bn1 | awk '/Cpu\(s\)/ {print 100-$8}')
        memory=$(free | awk '/Mem:/ {printf "%.1f", $3/$2*100}')
        load=$(awk '{print $1}' /proc/loadavg)
        pods=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l)
        clusters=$(kubectl get clusters -A --no-headers 2>/dev/null | wc -l)
        echo "${timestamp},${cpu},${memory},${load},${pods},${clusters}" \
            >> "${RESULT_FILE}"
        sleep "${INTERVAL}"
    done
}

load() {

    local manifest_prefix="$1"
    local i username pid
    local pids=()

    for ((i=1;i<=TOTAL_USERS;i++)); do
        username="user${i}"
        sudo -u "${username}" bash -lc "
            cd ~/cnpg-hands-on &&
            kubectl apply -f manifests/${manifest_prefix}-${username}.yaml
        " >/dev/null 2>&1 &
        pids+=("$!")
    done

    echo "Waiting for apply commands..."

    for pid in "${pids[@]}"; do
      wait "$pid"
    done

    echo "Apply commands finished."
}

count_healthy_clusters() {
    kubectl get clusters -A --no-headers 2>/dev/null \
        | grep "cnpg-cluster-user" \
        | grep -c "Cluster in healthy state" || true
}

wait_all_clusters_reconciled() {
    local healthy
    local expected="${TOTAL_USERS}"

    echo "Waiting for reconciliation to start..."

    while true; do
        healthy="$(count_healthy_clusters)"
        echo "Healthy clusters: ${healthy}/${expected}"

        if [[ "${healthy}" -lt "${expected}" ]]; then
            echo "Reconciliation started."
            break
        fi

        sleep 2
    done

    echo "Waiting for all clusters to become healthy again..."

    while true; do
        healthy="$(count_healthy_clusters)"
        echo "Healthy clusters: ${healthy}/${expected}"

        if [[ "${healthy}" -ge "${expected}" ]]; then
            echo "All clusters are healthy."
            break
        fi

        sleep 10
    done
}

report() {

    echo "Load Test Report"
    awk -F, '
        NR==2 {
            max_cpu=$2
            max_mem=$3
        }
        NR>1 {
            if($2>max_cpu) max_cpu=$2
            if($3>max_mem) max_mem=$3
        }
        END {
            printf "Max CPU    : %.1f %%\n", max_cpu
            printf "Max Memory : %.1f %%\n", max_mem
        }
    ' "${RESULT_FILE}"

    echo "Metrics saved in ${RESULT_FILE}"
}

cleanup() {
    if [[ -n "${MONITOR_PID}" ]]; then
        kill "${MONITOR_PID}" 2>/dev/null || true
        wait "${MONITOR_PID}" 2>/dev/null || true
        MONITOR_PID=""
    fi
}

main() {
    trap cleanup EXIT

    monitor &
    MONITOR_PID=$!

    load "01-cnpg-cluster"
    wait_all_clusters_reconciled || echo "Timeout waiting for clusters reconciliation"

    load "02-cnpg-cluster-barman-plugin"
    wait_all_clusters_reconciled || echo "Timeout waiting for clusters reconciliation"
    sleep 30

    cleanup

    report
}

main "$@"