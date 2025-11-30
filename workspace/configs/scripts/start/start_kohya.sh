#!/usr/bin/env bash
export PYTHONUNBUFFERED=1

echo "KOHYA_SS: Starting Kohya_ss Web UI"

source /workspace/.cache/venvs/kohya_ss/bin/activate

cd /workspace/apps/kohya_ss

export HF_HOME="/workspace/.cache/huggingface"

nohup ./gui.sh --listen 0.0.0.0 --server_port 3011 --headless >/workspace/.logs/kohya_ss.log 2>&1 &

echo "KOHYA_SS: Kohya_ss started"
echo "KOHYA_SS: Log file: /workspace/.logs/kohya_ss.log"
deactivate
