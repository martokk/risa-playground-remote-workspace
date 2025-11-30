#!/usr/bin/env bash
export PYTHONUNBUFFERED=1
echo "CODE SERVER: Starting Code Server"

mkdir -p /workspace/.logs

nohup code-server \
    --bind-addr 0.0.0.0:2000 \
    --auth none \
    --enable-proposed-api true \
    --disable-telemetry \
    /workspace &>/workspace/.logs/code-server.log &

echo "CODE SERVER: Code Server Started"
