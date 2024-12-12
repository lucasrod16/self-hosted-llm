#!/usr/bin/env bash

set -euo pipefail

terraform fmt
terraform validate
terraform init
terraform plan
terraform apply --auto-approve

INSTANCE_ID=$(terraform output -raw instance_id)
INSTANCE_IP=$(terraform output -raw instance_ip)

echo "Waiting for EC2 instance to be ready..."
aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID"

ssh-keyscan -H "$INSTANCE_IP" >> ~/.ssh/known_hosts
scp -p ./up.sh docker-compose.yml ubuntu@"$INSTANCE_IP":~/
ssh ubuntu@"$INSTANCE_IP" '$HOME/up.sh; nvidia-smi'

echo "Visit in the browser: http://${INSTANCE_IP}:8080"
