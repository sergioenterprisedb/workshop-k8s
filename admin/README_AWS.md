# Create VM
```
aws ec2 create-security-group \
--group-name 'launch-wizard-1' \
--description 'launch-wizard-1 created 2026-03-05T08:12:29.432Z' \
--vpc-id 'vpc-0f5f270ef0ed70171'

aws ec2 authorize-security-group-ingress \
--group-id 'sg-preview-1' \
--ip-permissions '{"IpProtocol":"tcp","FromPort":22,"ToPort":22,"IpRanges":[{"CidrIp":"0.0.0.0/0"}]}' '{"IpProtocol":"tcp","FromPort":443,"ToPort":443,"IpRanges":[{"CidrIp":"0.0.0.0/0"}]}' '{"IpProtocol":"tcp","FromPort":80,"ToPort":80,"IpRanges":[{"CidrIp":"0.0.0.0/0"}]}' 

aws ec2 run-instances \
--image-id 'ami-0c5c1b3399d21cdc6' \
--instance-type 't3.2xlarge' \
--key-name 'sergio-workshop' \
--network-interfaces '{"SubnetId":"subnet-0bf959ad0193dc461","AssociatePublicIpAddress":true,"DeviceIndex":0,"Groups":["sg-preview-1"]}' --credit-specification '{"CpuCredits":"unlimited"}' --tag-specifications '{"ResourceType":"instance","Tags":[{"Key":"Name","Value":"sergio-workshop"}]}' --metadata-options '{"HttpEndpoint":"enabled","HttpPutResponseHopLimit":2,"HttpTokens":"required"}' --private-dns-name-options '{"HostnameType":"ip-name","EnableResourceNameDnsARecord":false,"EnableResourceNameDnsAAAARecord":false}' \
--count '1' 
```

# Disks
Create 2 volumes and attach to the instance.

## Format and mount disks
```
# Create the mount points
sudo mkdir -p /mnt/disk1 /mnt/disk2 /mnt/disk3

# Format the disks (Warning: this wipes data on these specific volumes)
sudo mkfs -t xfs /dev/xvdb
sudo mkfs -t xfs /dev/xvdc
sudo mkfs -t xfs /dev/xvdd

# Mount them
sudo mount /dev/xvdb /mnt/disk1
sudo mount /dev/xvdc /mnt/disk2
sudo mount /dev/xvdd /mnt/disk3

lsblk -f
```
Add to /etc/fstab
```
lsblk -f
NAME      FSTYPE FSVER LABEL UUID                                 FSAVAIL FSUSE% MOUNTPOINTS
xvda                                                                             
├─xvda1   xfs          /     96e83033-9c05-4912-8900-93256ded3e51 1012.5M    88% /
├─xvda127                                                                        
└─xvda128 vfat   FAT16       C42B-0705                               8.7M    13% /boot/efi
xvdb      xfs                8b063de1-bca5-4098-8b0d-b187ed249464    7.9G     1% /mnt/disk1
xvdc      xfs                fb3797ac-c105-4746-b20e-2cdadeb79b8e    7.9G     1% /mnt/disk2
xvdd      xfs                641f4581-8c0c-4559-9771-3aa6c9a69a0c    7.9G     1% /mnt/disk3

UUID=8b063de1-bca5-4098-8b0d-b187ed249464 /mnt/disk1 xfs defaults,nofail 0 2
UUID=fb3797ac-c105-4746-b20e-2cdadeb79b8e /mnt/disk2 xfs defaults,nofail 0 2
UUID=641f4581-8c0c-4559-9771-3aa6c9a69a0c /mnt/disk3 xfs defaults,nofail 0 2
```
# Install
Install main components:
- Docker
- k3d
- kubectl

And other software:
-  bat
- htop
- cmclt
- rich

With ec2-user:
```
install_EC2.sh
```
Install minio:
```
cd ~/workshop-k8s/admin/minio
install_minio.sh
```

Install Prometheus and Grafana:
```
cd ~/workshop-k8s/admin/prometheus
./install_prometheus.sh
```

Install linux users (by default 10 in `config.sh`file):
```
cd ~/workshop-k8s/admin/
./create_linux_users.sh
```


