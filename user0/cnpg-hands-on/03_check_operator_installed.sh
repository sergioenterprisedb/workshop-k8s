#!/bin/bash

source ./config.sh

print_command "${kubectl_cmd} get deploy -n cnpg-system cnpg-controller-manager\n"

blue="\033[34m"
reset="\033[0m"
${kubectl_cmd} get deploy -A | grep cnpg | awk \
-v blue="${blue}" -v reset="${reset}" '{
  printf "%s%-14s%s %s\n", blue, "NAMESPACE:", reset, $1
  printf "%s%-14s%s %s\n", blue, "NAME:", reset, $2
  printf "%s%-14s%s %s\n", blue, "READY:", reset, $3
  printf "%s%-14s%s %s\n", blue, "UP-TO-DATE:", reset, $4
  printf "%s%-14s%s %s\n", blue, "AVAILABLE:", reset, $5
  printf "%s%-14s%s %s\n", blue, "AGE:", reset, $6
}'