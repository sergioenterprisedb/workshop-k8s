#!/bin/bash

export TOTAL_USERS=10
export INSTALL_ENV="EC2"         # EC2|VAGRANT
export ENV_USER="ec2-user"       # ec2-user|vagrant
export SOURCE_CNP_PATH=/${ENV_USER}/user0/cnpg-hands-on
export K3D_CLUSTER=workshop