#!/bin/bash
# -----------------------------------------------------------------------------
# infra/templates/user-data.sh
# Formats and mounts the 3 EBS volumes on first boot.
# All other instance preparation is handled by provision.sh.
# The shebang MUST stay the first line — EC2 only runs user-data starting with #!.
# -----------------------------------------------------------------------------
set -eux
exec >> /var/log/workshop-init.log 2>&1

sleep 20
mkfs -t ext4 /dev/xvdb
mkfs -t ext4 /dev/xvdc
mkfs -t ext4 /dev/xvdd
mkdir -p /mnt/disk1 /mnt/disk2 /mnt/disk3
mount /dev/xvdb /mnt/disk1
mount /dev/xvdc /mnt/disk2
mount /dev/xvdd /mnt/disk3
echo "/dev/xvdb /mnt/disk1 ext4 defaults,nofail 0 2" >> /etc/fstab
echo "/dev/xvdc /mnt/disk2 ext4 defaults,nofail 0 2" >> /etc/fstab
echo "/dev/xvdd /mnt/disk3 ext4 defaults,nofail 0 2" >> /etc/fstab
