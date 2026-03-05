#!/bin/bash

. ./config

# Install clusters
for (( i=1; i<=$TOTAL_USERS; i++ ))
do
  username="user$i"
  sudo su - ${username} -c "./06_get_cluster_config_file.sh"
  sudo su - ${username} -c "./07_install_cluster.sh"
done
