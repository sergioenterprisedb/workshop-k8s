#!/bin/bash

#git_directory=`git rev-parse --show-toplevel`
#. ${git_directory}/commands.sh

# ╭──────────────────────────────╮
# │        TMP directory         │
# ╰──────────────────────────────╯

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export TMP=${DIR}/tmp
[ -d $TMP ] || mkdir $TMP
source ./commands.sh

#echo ""
#echo "Find the YAML-files in $TMP"
#echo ""

# ╭──────────────────────────────╮
# │        Set OS platform       │
# ╰──────────────────────────────╯

export os_platform=$(uname)
export k8s_tool="k3d" # valid options: "k3d" or "kind"
export k8s_cluster_name="cluster-`whoami`"

# ╭──────────────────────────────╮
# │    Kubernetes environment    │
# ╰──────────────────────────────╯
export namespace="ns-`whoami`"
export kubectl_cmd="kubectl"    # could be kubectl|oc
export kubectl_cnp="kubectl-cnpg"

# ╭──────────────────────────────╮
# │            Barman            │
# ╰──────────────────────────────╯

export cert_manager_version="v1.18.2"
export plugin_barman_version="v0.11.0"
export barman_object_name="object-store"
export barman_retention_policy="30d"

# local IP:
export os_platform=$(uname)
# if [[ "${os_platform}" == "Darwin" ]]
# then
#    export local_ip=`ifconfig en0 inet | awk '/inet6/ {next} /inet/ {print $2}'`
# elif [[ "${os_platform}" == "Linux" ]]
# then
#    #export local_ip=`hostname -I | awk '{print $1}'`
#    export local_ip=$(ip route get 1 | awk '{print $7; exit}')
# fi

# ╭──────────────────────────────╮
# │            Postgres          │
# ╰──────────────────────────────╯

# Templates
export cluster_name_template="cluster-example"
export cluster_restore_template="cluster-restore-example"
export cluster_major_upgrade_template="cluster-example-17-example"

# User
export cluster_name="cluster-`whoami`"
export cluster_restore="cluster-restore-`whoami`"
export cluster_major_upgrade="cluster-example-17-`whoami`"
export postgres_instances=3
export postgres_cpu="0.5"
export postgres_max_cpu="0.5"
export postgres_memory="512Mi"
export postgres_max_memory="512Mi" # "1Gi"
export postgres_storage="512Mi"
export postgres_wal_storage="512Mi"
export postgres_idx_storage="512Mi"
export postgres_tmp_storage="512Mi"
export postgres_idx_storage="512Mi"
export postgres_default_image="quay.io/enterprisedb/postgresql:16.4"
export postgres_minor_upgrade_image="quay.io/enterprisedb/postgresql:16.5"
export postgres_major_upgrade_image="quay.io/enterprisedb/postgresql:17"

# ╭──────────────────────────────╮
# │             EPAS             │
# ╰──────────────────────────────╯

export epas_image="docker.enterprisedb.com/k8s_enterprise/edb-postgres-advanced:17.2"
export epas_storage="512Mi"

# ╭──────────────────────────────╮
# │        Object Storage        │
# ╰──────────────────────────────╯

# Object Storage environment [minio|aws|azure]
export object_storage_type="minio"

if [ "$object_storage_type" = "minio" ]; then

  ## Minio
  export ACCESS_KEY_ID="admin"
  export ACCESS_SECRET_KEY="password"
  export ACCESS_SESSION_TOKEN=""
  export s3_bucket="backups"
  export minio_port=9000
  #export local_ip=`ifconfig en0 inet | awk '/inet6/ {next} /inet/ {print $2}'`
  export local_ip="10.0.2.15"
  export object_storage_bucket="${bucket}"
  export s3_destination_path="s3://${bucket}/"
  #export s3_endpoint_url="https://minio-api-minio.apps.cluster-cx9nq.dynamic.redhatworkshops.io"
  export s3_endpoint_url="http://10.0.2.15:9000"

fi
