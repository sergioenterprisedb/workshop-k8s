#!/bin/bash

. ./config.sh

# Delete clusters
for (( i=1; i<=$TOTAL_USERS; i++ ))
do
  username="user$i"
  sudo su - ${username} -c "kubectl delete backup  cluster-${username}-backup-test"
  sudo su - ${username} -c "kubectl delete cluster cluster-${username}"
done
