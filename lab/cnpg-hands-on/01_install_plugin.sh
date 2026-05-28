#!/bin/bash

source ./config.sh

print_info "Install cnpg plugin\n"

print_command "curl -sSfL \
https://github.com/cloudnative-pg/cloudnative-pg/raw/main/hack/install-cnpg-plugin.sh | \
sh -s -- -b ${HOME}/cnpg\n"

curl -sSfL \
https://github.com/cloudnative-pg/cloudnative-pg/raw/main/hack/install-cnpg-plugin.sh | \
sudo sh -s -- -b /usr/local/bin

print_info "Pluging ${kubectl_cnp} installed\n"
