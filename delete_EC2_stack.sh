#!/bin/bash

set -euo pipefail

# -----------------------------
# CONFIG
# -----------------------------
REGION="eu-west-3"
TAG_NAME="sergio-workshop-test"

echo "🔍 Finding resources with tag: $TAG_NAME"

# -----------------------------
# FIND INSTANCE
# -----------------------------
INSTANCE_ID=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$TAG_NAME" \
            "Name=instance-state-name,Values=running,stopped,pending" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)

if [[ -z "${INSTANCE_ID:-}" ]]; then
  echo "⚠️ No instance found"
else
  echo "🖥 Terminating instance: $INSTANCE_ID"

  aws ec2 terminate-instances \
    --instance-ids $INSTANCE_ID \
    --region "$REGION"

  aws ec2 wait instance-terminated \
    --instance-ids $INSTANCE_ID \
    --region "$REGION"

  echo "✅ Instance terminated"
fi

# -----------------------------
# FIND VPC
# -----------------------------
VPC_ID=$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$TAG_NAME-vpc" \
  --query "Vpcs[0].VpcId" \
  --output text)

if [[ "$VPC_ID" == "None" || -z "$VPC_ID" ]]; then
  echo "⚠️ No VPC found"
  exit 0
fi

echo "🌐 VPC: $VPC_ID"

# -----------------------------
# DELETE SECURITY GROUPS
# -----------------------------
SG_IDS=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[?GroupName!='default'].GroupId" \
  --output text)

for SG in $SG_IDS; do
  echo "🔐 Deleting SG: $SG"
  aws ec2 delete-security-group \
    --group-id "$SG" \
    --region "$REGION" || true
done

# -----------------------------
# DELETE SUBNETS
# -----------------------------
SUBNET_IDS=$(aws ec2 describe-subnets \
  --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[].SubnetId" \
  --output text)

# -----------------------------
# ROUTE TABLES
# -----------------------------
aws ec2 describe-route-tables \
  --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "RouteTables[].RouteTableId" \
  --output text | tr '\t' '\n' | while read -r RT; do

  [[ -z "$RT" ]] && continue

  echo "Processing RT: $RT"

  MAIN=$(aws ec2 describe-route-tables \
    --route-table-ids "$RT" \
    --region "$REGION" \
    --query "RouteTables[0].Associations[?Main==\`true\`]" \
    --output text)

  if [[ -n "$MAIN" ]]; then
    echo "Skipping main route table: $RT"
    continue
  fi

  ASSOC_IDS=$(aws ec2 describe-route-tables \
    --route-table-ids "$RT" \
    --region "$REGION" \
    --query "RouteTables[0].Associations[].RouteTableAssociationId" \
    --output text)

  for A in $ASSOC_IDS; do
    [[ "$A" == "None" || -z "$A" ]] && continue
    aws ec2 disassociate-route-table \
      --association-id "$A" \
      --region "$REGION" || true
  done

  echo "🛣 Deleting Route Table: $RT"
  aws ec2 delete-route-table \
    --route-table-id "$RT" \
    --region "$REGION" || true

done

# -----------------------------
# INTERNET GATEWAY
# -----------------------------
IGW_ID=$(aws ec2 describe-internet-gateways \
  --region "$REGION" \
  --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  --query "InternetGateways[0].InternetGatewayId" \
  --output text)

if [[ "$IGW_ID" != "None" ]]; then
  echo "🌍 Detaching & deleting IGW: $IGW_ID"

  aws ec2 detach-internet-gateway \
    --internet-gateway-id "$IGW_ID" \
    --vpc-id "$VPC_ID" \
    --region "$REGION"

  aws ec2 delete-internet-gateway \
    --internet-gateway-id "$IGW_ID" \
    --region "$REGION"
fi

# -----------------------------
# DELETE SUBNETS
# -----------------------------
for SUBNET in $SUBNET_IDS; do
  echo "📦 Deleting Subnet: $SUBNET"
  aws ec2 delete-subnet \
    --subnet-id "$SUBNET" \
    --region "$REGION" || true
done

# -----------------------------
# DELETE VPC
# -----------------------------
echo "🔥 Deleting VPC: $VPC_ID"

aws ec2 delete-vpc \
  --vpc-id "$VPC_ID" \
  --region "$REGION"

echo "-----------------------------------"
echo "✅ Cleanup complete"
echo "-----------------------------------"
