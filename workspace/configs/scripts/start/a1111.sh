#!/usr/bin/env bash
export PYTHONUNBUFFERED=1

echo "\nA1111: Starting Stable Diffusion Web UI"

cd /apps/stable-diffusion-webui

export HF_HOME="/workspace/.cache/huggingface"

nohup /apps/stable-diffusion-webui/webui.sh -f >/workspace/.logs/webui.log 2>&1 &

echo "\nA1111: Stable Diffusion Web UI started"
echo "A1111: Log file: /workspace/.logs/webui.log\n"
