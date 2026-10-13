#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if command -v swift >/dev/null; then
    swift test
elif command -v docker >/dev/null; then
    env -u DOCKER_HOST -u DOCKER_CONTEXT -u DOCKER_TLS -u DOCKER_TLS_VERIFY -u DOCKER_CERT_PATH \
        docker --host=unix:///var/run/docker.sock run --rm \
        --mount "type=bind,src=$PWD,dst=/app" --workdir /app \
        swift:6.0-bookworm swift test
else
    echo 'Install Swift 6.0+ or Docker to run the shared logic tests.' >&2
    exit 1
fi
