#!/bin/bash

. ./config.sh

# Install clusters
for (( i=1; i<=$TOTAL_USERS; i++ ))
do
  username="user$i"
  sudo su - ${username} -c "./10_backup_cluster.sh"
done
