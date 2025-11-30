#!/usr/bin/env bash
export PYTHONUNBUFFERED=1
echo "JUPYTER: Starting Jupyter Lab"

# Default to not using a password
JUPYTER_PASSWORD=""

# Allow a password to be set by providing the JUPYTER_PASSWORD environment variable
if [[ ${JUPYTER_LAB_PASSWORD} ]]; then
    JUPYTER_PASSWORD=${JUPYTER_LAB_PASSWORD}
fi

cd / &&
    nohup jupyter lab --allow-root \
        --no-browser \
        --port=2010 \
        --ip=* \
        --FileContentsManager.delete_to_trash=False \
        --ContentsManager.allow_hidden=True \
        --ServerApp.terminado_settings='{"shell_command":["/bin/bash"]}' \
        --ServerApp.token=${JUPYTER_PASSWORD} \
        --ServerApp.allow_origin=* \
        --ServerApp.preferred_dir=/workspace &>/workspace/.logs/jupyter.log &

echo "JUPYTER: Jupyter Lab Started"
