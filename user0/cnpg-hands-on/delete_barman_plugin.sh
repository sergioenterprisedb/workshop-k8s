#!/bin/bash

source ./config.sh

${kubectl_cmd} delete -f https://github.com/cloudnative-pg/plugin-barman-cloud/releases/download/${plugin_barman_version}/manifest.yaml
