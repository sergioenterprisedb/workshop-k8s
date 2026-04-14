#!/bin/bash

set -euo pipefail

# -----------------------------
# CONFIGURATION
# -----------------------------
REGION="eu-west-3"
INSTANCE_TYPE="t2.2xlarge"
KEY_NAME="sergio-workshop"

MY_CIDR="163.0.0.0/8"
TAG_NAME="sergio-workshop-test"

# Network
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.1.0/24"

# Logs
mkdir -p ./log
LOG_FILE="./log/cleanup_$(date +'%Y%m%d_%H%M%S').log"
exec > >(tee -a "$LOG_FILE") 2>&1

# -----------------------------
# CREATE VPC
# -----------------------------
echo "Creating VPC..."

VPC_ID=$(aws ec2 create-vpc \
  --cidr-block "$VPC_CIDR" \
  --region "$REGION" \
  --query "Vpc.VpcId" \
  --output text)

aws ec2 create-tags --resources "$VPC_ID" \
  --region "$REGION" \
  --tags Key=Name,Value="$TAG_NAME-vpc"

echo "VPC: $VPC_ID"

# Enable DNS
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" \
  --enable-dns-support "{\"Value\":true}" --region "$REGION"

aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" \
  --enable-dns-hostnames "{\"Value\":true}" --region "$REGION"

# -----------------------------
# CREATE INTERNET GATEWAY
# -----------------------------
echo "Creating Internet Gateway..."

IGW_ID=$(aws ec2 create-internet-gateway \
  --region "$REGION" \
  --query "InternetGateway.InternetGatewayId" \
  --output text)

aws ec2 attach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID" \
  --region "$REGION"

echo "IGW: $IGW_ID"

# -----------------------------
# CREATE SUBNET
# -----------------------------
echo "Creating Subnet..."

SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block "$SUBNET_CIDR" \
  --region "$REGION" \
  --query "Subnet.SubnetId" \
  --output text)

aws ec2 modify-subnet-attribute \
  --subnet-id "$SUBNET_ID" \
  --map-public-ip-on-launch \
  --region "$REGION"

echo "Subnet: $SUBNET_ID"

# -----------------------------
# ROUTE TABLE
# -----------------------------
echo "Configuring routing..."

RT_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --region "$REGION" \
  --query "RouteTable.RouteTableId" \
  --output text)

aws ec2 create-route \
  --route-table-id "$RT_ID" \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id "$IGW_ID" \
  --region "$REGION"

aws ec2 associate-route-table \
  --route-table-id "$RT_ID" \
  --subnet-id "$SUBNET_ID" \
  --region "$REGION"

# -----------------------------
# SECURITY GROUP
# -----------------------------
echo "Creating Security Group..."

SG_ID=$(aws ec2 create-security-group \
  --group-name "$TAG_NAME-sg" \
  --description "EC2 SG" \
  --vpc-id "$VPC_ID" \
  --region "$REGION" \
  --query "GroupId" \
  --output text)

# SSH
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr "$MY_CIDR" \
  --region "$REGION"

# Grafana
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 3010 \
  --cidr "0.0.0.0/0" \
  --region "$REGION"
  
# MinIO
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 9010 \
  --cidr "0.0.0.0/0" \
  --region "$REGION"

# Shellinabox
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 4200 \
  --cidr "0.0.0.0/0" \
  --region "$REGION"

echo "SG: $SG_ID"

# -----------------------------
# AMAZON LINUX AMI
# -----------------------------
echo "Fetching AMI..."

AMI_ID=$(aws ec2 describe-images \
  --region "$REGION" \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" \
  --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" \
  --output text)

echo "AMI: $AMI_ID"

# -----------------------------
# USER DATA
# -----------------------------
USER_DATA=$(cat <<'EOF'
#!/bin/bash
set -eux

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
EOF
)

# -----------------------------
# LAUNCH INSTANCE
# -----------------------------
echo "Launching EC2..."

INSTANCE_ID=$(aws ec2 run-instances \
  --region "$REGION" \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --subnet-id "$SUBNET_ID" \
  --associate-public-ip-address \
  --block-device-mappings '[
    {"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":50,"VolumeType":"gp3","Iops":6000,"Throughput":300,"DeleteOnTermination":true}},
    {"DeviceName":"/dev/xvdb","Ebs":{"VolumeSize":50,"VolumeType":"gp3","Iops":6000,"Throughput":300,"DeleteOnTermination":true}},
    {"DeviceName":"/dev/xvdc","Ebs":{"VolumeSize":50,"VolumeType":"gp3","Iops":6000,"Throughput":300,"DeleteOnTermination":true}},
    {"DeviceName":"/dev/xvdd","Ebs":{"VolumeSize":50,"VolumeType":"gp3","Iops":6000,"Throughput":300,"DeleteOnTermination":true}}
  ]' \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG_NAME}]" \
  --user-data "$USER_DATA" \
  --query "Instances[0].InstanceId" \
  --output text)

echo "Instance: $INSTANCE_ID"

# -----------------------------
# WAIT + OUTPUT
# -----------------------------
aws ec2 wait instance-running \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION"

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "-----------------------------------"
echo "✅ EC2 READY"
echo "IP: $PUBLIC_IP"
echo "SSH:"
echo "ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP"
echo "ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP" > ./connect_ec2.sh
chmod +x ./connect_ec2.sh
echo "-----------------------------------"
