#!/usr/bin/env bash
export PYTHONUNBUFFERED=1

echo "INVOKEAI: Starting InvokeAI"

source /workspace/.cache/venvs/invokeai/bin/activate

cd /apps/InvokeAI
nohup invokeai-web --root /apps/InvokeAI >/workspace/.logs/invokeai.log 2>&1 &

echo "INVOKEAI: InvokeAI started"
echo "INVOKEAI: Log file: /workspace/.logs/invokeai.log"
deactivate
