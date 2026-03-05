#!/bin/bash

source ./config.sh

i=$1
case $i in
  "on")
    print_command "${kubectl_cmd} annotate cluster ${cluster_name} --overwrite cnpg.io/hibernation=${i}\n"
    ${kubectl_cmd} annotate cluster ${cluster_name} --overwrite cnpg.io/hibernation=${i}
    ;;
  "off")
    print_command "${kubectl_cmd} annotate cluster ${cluster_name} --overwrite cnpg.io/hibernation=${i}\n"
    ${kubectl_cmd} annotate cluster ${cluster_name} --overwrite cnpg.io/hibernation=${i}
    ;;
  *)
    echo "usage: $0 on|off"
    exit
esac
