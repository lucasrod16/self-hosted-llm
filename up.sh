#!/usr/bin/env bash

set -euo pipefail

cloud-init status --wait --long
sudo docker compose up -d
curl -f "http://localhost:11434/api/pull" -d '{"name": "llama3.3"}'
# preload model and leave it in memory 
curl -f "http://localhost:11434/api/generate" -d '{"model": "llama3.3", "keep_alive": -1}'
