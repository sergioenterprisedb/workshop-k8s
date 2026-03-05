#!/bin/bash

username=$1

kubectl-cnpg -n ns-${username} --color always status cluster-${username}
