#!/bin/bash

set -euo pipefail

URL="http://localhost:11434"

health_check() {
    local retry_limit=5
    local retry_interval=1
    until curl -f -s "$URL" > /dev/null; do
        if (( retry_limit-- <= 0 )); then
            echo "Health check failed after $retry_limit attempts."
            exit 1
        fi
        echo "Health check failed, retrying in $retry_interval second..."
        sleep "$retry_interval"
    done
    echo "Health check passed!"
}

pull_model() {
    curl -f "${URL}/api/pull" -d '{"name": "llama3.2"}'
}

docker compose up -d
health_check
pull_model
