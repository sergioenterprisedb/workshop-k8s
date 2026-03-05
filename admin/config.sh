#!/bin/bash

export TOTAL_USERS=10
export INSTALL_ENV="EC2"         # EC2|VAGRANT
export ENV_USER="ec2-user"       # ec2-user|vagrant
#export SOURCE_CNP_PATH=/vagrant/user0/cnpg-hands-on
export SOURCE_ADMIN_PATH=/home/${ENV_USER}/workshop-k8s/admin
export SOURCE_CNP_PATH=/home/${ENV_USER}/workshop-k8s/user0/cnpg-hands-on
export K3D_CLUSTER=workshop