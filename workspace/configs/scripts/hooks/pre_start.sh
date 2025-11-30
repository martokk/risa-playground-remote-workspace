#!/usr/bin/env bash

sync_directory() {
    local src_dir="$1"
    local dst_dir="$2"

    echo "SYNC: Syncing from ${src_dir} to ${dst_dir}, please wait (this can take a few minutes)..."

    # Ensure destination directory exists
    mkdir -p "${dst_dir}"

    # Free up memory by clearing page cache, dentries, and inodes.
    # This requires root privileges.
    sync
    if [ -w /proc/sys/vm/drop_caches ]; then
        echo 3 >/proc/sys/vm/drop_caches
    fi

    # Using rsync as it can be more memory-efficient than cp for large numbers of files.
    # -a: archive mode (preserves attributes, copies recursively)
    # -u: update (copies only when the SOURCE file is newer than the destination file or when the destination file is missing)
    rsync -au "${src_dir}/" "${dst_dir}/"

    # Remove the source directory
    rm -rf "${src_dir}"

}

sync_apps() {
    echo "PRE-START: SYNCING APPLICATIONS ------------------------------------------------"

    # Start the timer
    start_time=$(date +%s)

    # echo "SYNC: Sync /configs"
    # sync_directory "/configs" "/workspace/configs"

    # echo "SYNC: Sync /scripts"
    # sync_directory "/scripts" "/workspace/configs/scripts"

    # echo "SYNC: Sync /apps"
    # sync_directory "/apps" "/workspace/apps"

    echo "SYNC: Sync /venvs"
    for venv_name in a1111 comfyui invokeai kohya_ss risa; do
        # Only sync if the destination venv does not exist and the source venv exists.
        if [[ ! -d "/workspace/.cache/venvs/${venv_name}" && -d "/venvs/${venv_name}" ]]; then
            sync_directory "/venvs/${venv_name}" "/workspace/.cache/venvs/${venv_name}"
        fi
    done

    # End the timer and calculate the duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    # Convert duration to minutes and seconds
    minutes=$((duration / 60))
    seconds=$((duration % 60))

    echo "SYNC: Syncing COMPLETE!"
    printf "SYNC: Time taken: %d minutes, %d seconds\n" ${minutes} ${seconds}
}

create_symlinks() {
    local symlinks_config="/workspace/configs/symlinks.yaml"

    if [[ ! -f "${symlinks_config}" ]]; then
        echo "SYMLINK: Config file not found at ${symlinks_config}. Skipping."
        return
    fi

    yq -r '[.[] | .source, .destination] | join("\u0000")' "${symlinks_config}" | while IFS= read -r -d '' source && IFS= read -r -d '' destination; do
        # Remove trailing slashes
        source="${source%/}"
        destination="${destination%/}"

        if [[ -z "$source" || -z "$destination" ]]; then
            echo "SYMLINK: ERROR: Skipping invalid entry (source: ${source}, destination: ${destination})"
            continue
        fi

        echo "SYMLINK: Processing link from '${source}' to '${destination}'"

        # If source does not exist but destination does, move destination to source.
        if [[ ! -e "${source}" && ! -L "${source}" && -e "${destination}" && ! -L "${destination}" ]]; then
            echo "SYMLINK: MOVE: Source '${source}' not found, but destination '${destination}' exists. Moving it."
            mkdir -p "$(dirname "${source}")"
            mv "${destination}" "${source}"
            echo "SYMLINK: MOVE: Move complete. '${destination}' is now at '${source}'."
        fi

        # After the potential move, if source still doesn't exist, we can't do anything.
        if [[ ! -e "${source}" && ! -L "${source}" ]]; then
            echo "SYMLINK: ERROR: Source '${source}' does not exist. Cannot create symlink. Skipping."
            continue
        fi

        # Now, source exists. Let's prepare the destination.
        if [[ -L "${destination}" ]]; then
            # Destination is a symlink. Check if it's correct.
            if [[ "$(readlink -f "${destination}")" == "$(readlink -f "${source}")" ]]; then
                echo "SYMLINK: OK: Symlink already exists"
                continue
            else
                echo "SYMLINK: ERROR: Incorrect symlink at '${destination}'. Removing it."
                rm "${destination}"
            fi
        elif [[ -e "${destination}" ]]; then
            # Destination exists and is a file or directory. This happens if both source and destination existed initially.
            # We back up the destination.
            destination_no_slash="${destination%/}"
            echo "SYMLINK: Destination '${destination}' already exists. Renaming to '${destination_no_slash}.old'."
            if [[ -e "${destination_no_slash}.old" || -L "${destination_no_slash}.old" ]]; then
                rm -rf "${destination_no_slash}.old"
            fi
            mv "${destination}" "${destination_no_slash}.old"
        fi

        # Destination path is now clear. Create the symlink.
        echo "SYMLINK: CREATE: Creating symlink from '${source}' to '${destination}'"
        mkdir -p "$(dirname "${destination}")"
        ln -s "${source}" "${destination}"
    done

    echo "SYMLINK: Symlink creation complete."
}

relocate_venvs() {
    echo "VENV: Fixing Kohya venv..."
    /workspace/configs/scripts/venv/relocate_venv.sh /venvs/kohya_ss /workspace/.cache/venvs/kohya_ss

    echo "VENV: Fixing ComfyUI venv..."
    /workspace/configs/scripts/venv/relocate_venv.sh /venvs/comfyui /workspace/.cache/venvs/comfyui
}

setup_workspace() {
    echo "WORKSPACE: Checking workspace setup..."
    
    if [[ ! -d "/workspace" ]]; then
        echo "WORKSPACE: /workspace not found. Cloning base repository..."
        cd /
        git clone https://github.com/martokk/risa-workspace-base workspace
        echo "WORKSPACE: Repository cloned successfully."
    else
        echo "WORKSPACE: /workspace exists. Continuing..."
    fi
}

create_directories() {
    mkdir -p /workspace/.cache/venvs
    mkdir -p /workspace/.logs
    mkdir -p /workspace/__INPUTS__/comfyui
    mkdir -p /workspace/__INPUTS__/kohya_ss
    mkdir -p /workspace/__INPUTS__/risa
    mkdir -p /workspace/__OUTPUTS__/comfyui
    mkdir -p /workspace/__OUTPUTS__/kohya_ss
    mkdir -p /workspace/__OUTPUTS__/risa
    mkdir -p /workspace/configs/scripts
    mkdir -p /workspace/configs/webdav
    mkdir -p /workspace/configs/kohya_ss
    mkdir -p /workspace/configs/comfyui
    mkdir -p /workspace/configs/risa
    mkdir -p /workspace/models
    mkdir -p /workspace/workflows
}

start_nginx() {
    echo "NGINX: Starting Nginx service..."
    service nginx start
}

ensure_scripts_executable() {
    echo "PERMISSIONS: Ensuring start scripts are executable..."
    chmod +x /workspace/configs/scripts/start/*.sh 2>/dev/null || true
}

echo "PRE-START: START ---------------------------------------------------------------"

export PYTHONUNBUFFERED=1

echo "COPY SSH KEYS ------------------------------------------------------------------"
mkdir -p /root/.ssh
cp /workspace/configs/.ssh/id_risa_playground /root/.ssh/
chmod 600 /root/.ssh/id_risa_playground
cp /workspace/configs/.ssh/id_risa_playground.pub /root/.ssh/
chmod 644 /root/.ssh/id_risa_playground.pub

echo "PRE-START: SETUP WORKSPACE -----------------------------------------------------"
setup_workspace

echo "PRE-START: STRUCTURING DIRECTORIES ---------------------------------------------"
create_directories

echo "PRE-START: SYNCING APPLICATIONS ------------------------------------------------"
sync_apps

echo "PRE-START: CREATING SYMLINKS ---------------------------------------------------"
create_symlinks

echo "PRE-START: RELOCATE VENVS ---------v-----------------------------------------------"
relocate_venvs

echo "PRE-START: CONFIGURING ACCELERATE ----------------------------------------------"
mkdir -p /root/.cache/huggingface/accelerate
mv /accelerate.yaml /root/.cache/huggingface/accelerate/default_config.yaml

echo "PRE-START: LAUNCHING APPLICATIONS ----------------------------------------------"

echo "ENV VARIABLES"
echo "==================="
echo "CPU_ONLY=${CPU_ONLY}"
echo "START_CODE_SERVER=${START_CODE_SERVER}"
echo "START_JUPYTER=${START_JUPYTER}"
echo "START_WEBDAV=${START_WEBDAV}"
echo "START_TENSORBOARD=${START_TENSORBOARD}"
echo "START_COMFYUI=${START_COMFYUI}"
echo "START_KOHYA=${START_KOHYA}"
echo "START_RISA_PLAYGROUND=${START_RISA_PLAYGROUND}"
echo "UNISONLOCALHOSTNAME=${UNISONLOCALHOSTNAME}"

export UNISONLOCALHOSTNAME=${UNISONLOCALHOSTNAME}

start_nginx

ensure_scripts_executable

if [ ${START_JUPYTER} ]; then
    echo "   ---- LAUNCHING: Jupyter ----------------------------------------------------"
    /workspace/configs/scripts/start/jupyter.sh
fi

if [ ${START_CODE_SERVER} ]; then
    echo "   ---- LAUNCHING: Code Server ----------------------------------------------"
    /workspace/configs/scripts/start/code_server.sh
fi

if [ ${START_WEBDAV} ]; then
    echo "   ---- LAUNCHING: WebDAV -----------------------------------------------------"
    /workspace/configs/scripts/start/webdav.sh
fi

if [ ${START_TENSORBOARD} ]; then
    echo "   ---- LAUNCHING: TensorBoard ------------------------------------------------"
    /workspace/configs/scripts/start/tensorboard.sh
fi

if [ ${START_KOHYA} ]; then
    echo "   ---- LAUNCHING: Kohya_ss ------------------------------------------------------"
    /workspace/configs/scripts/start/kohya_ss.sh
fi

if [ ${START_COMFYUI} ]; then
    if [ ${CPU_ONLY} ]; then
        echo "   ---- LAUNCHING: ComfyUI (CPU ONLY) --------------------------------------"
        /workspace/configs/scripts/start/comfyui_cpu.sh
    else
        echo "   ---- LAUNCHING: ComfyUI (GPU) -------------------------------------------"
        /workspace/configs/scripts/start/comfyui.sh
    fi
fi

# if [ ${START_RISA_PLAYGROUND} ]; then
#     echo "   ---- LAUNCHING: Risa Playground ------------------------------------------"
#     /workspace/configs/scripts/start/risa.sh
# fi


echo "PRE-START: DONE ------------------------------------------------------------"
echo "----------------------------------------------------------------------------\n\n"
