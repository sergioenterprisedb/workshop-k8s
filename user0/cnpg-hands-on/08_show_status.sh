#!/bin/bash

source ./config.sh

watch -c -n 4 "${kubectl_cnp} -n ${namespace} --color always status ${cluster_name}"
