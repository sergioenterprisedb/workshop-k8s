#!/bin/bash

source ./replica.sh

i=$1
case $i in
  "on")
    print_command "${kubectl_cnp} fencing ${i} ${cluster_name} ${replica}\n"
    ${kubectl_cnp} fencing on ${cluster_name} ${replica}
    ;;
  "off")
    print_command "${kubectl_cnp} fencing ${i} ${cluster_name} ${replica}\n"
    ${kubectl_cnp} fencing ${i} ${cluster_name} ${replica}
    ;;
  *)
    echo "usage: $0 on|off"
    exit
esac
