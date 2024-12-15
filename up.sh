#!/usr/bin/env bash

set -euo pipefail

cloud-init status --wait --long
sudo docker compose up -d

# download model
echo "Downloading model...this could take a few minutes..."
curl -f "http://localhost:11434/api/pull" -d '{"name": "llama3.3"}'

# preload model and leave it in memory 
echo "Preloading model...this could take a few minutes..."
curl -f "http://localhost:11434/api/generate" -d '{"model": "llama3.3", "keep_alive": -1}'
