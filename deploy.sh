#!/usr/bin/env bash

set -euo pipefail

terraform init
terraform plan
terraform apply --auto-approve

INSTANCE_ID=$(terraform output -raw instance_id)
INSTANCE_IP=$(terraform output -raw instance_ip)

echo "Waiting for EC2 instance to be ready..."
aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID"
scp -p -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ./up.sh docker-compose.yml ubuntu@"$INSTANCE_IP":~/
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ubuntu@"$INSTANCE_IP" '$HOME/up.sh'
