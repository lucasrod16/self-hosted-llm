#!/usr/bin/env bash

set -euo pipefail

terraform init
terraform fmt
terraform validate
terraform plan
terraform apply --auto-approve

INSTANCE_ID=$(terraform output -raw instance_id)
INSTANCE_IP=$(terraform output -raw instance_ip)

echo "Waiting for EC2 instance to be ready..."
aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID"

ssh-keyscan -H "$INSTANCE_IP" >> ~/.ssh/known_hosts
scp -r docker/ docker-compose.yml ubuntu@"$INSTANCE_IP":~/

ssh ubuntu@"$INSTANCE_IP" << EOF
#!/usr/bin/env bash

set -euo pipefail

cloud-init status --wait --long

sudo docker compose down
sudo docker compose up -d

echo "Downloading llama 3.3 model...this could take a few minutes..."
curl -fsSL "http://localhost:11434/api/pull" -d '{"name": "llama3.3"}'

echo "Downloading deepseek-r1:70b model...this could take a few minutes..."
curl -fsSL "http://localhost:11434/api/pull" -d '{"name": "deepseek-r1:70b"}'

nvidia-smi
EOF

echo "Visit in the browser: http://${INSTANCE_IP}:8080"
