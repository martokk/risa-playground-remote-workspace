#!/usr/bin/env bash
export PYTHONUNBUFFERED=1

echo "COMFYUI: Starting ComfyUI"

source /workspace/.cache/venvs/comfyui/bin/activate


cd /workspace/configs/comfyui/custom_nodes/
rm -rf ComfyUI-Manager ComfyUI_Comfyroll_CustomNodes ComfyUI-TiledDiffusion Stand-In_Preprocessor_ComfyUI comfy-plasma comfyui-dazzlenodes comfyui-various comfy-image-saver ComfyLiterals ComfyUI-EsesImageResize ComfyUI-AutoCropFaces ComfyUI-FlashVSR_Ultra_Fast IPAdapterWAN comfyui-tensorops kaytool

# Clone repos without prompting for credentials - log errors and continue
LOGFILE="/workspace/.logs/comfyui.log"
clone_repo() {
    local repo_url="$1"
    local repo_name=$(basename "$repo_url" .git)
    echo "Cloning $repo_name..."
    if ! GIT_TERMINAL_PROMPT=0 git clone "$repo_url" 2>&1; then
        echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') Failed to clone $repo_url" >> "$LOGFILE"
    fi
}

clone_repo https://github.com/ltdrdata/ComfyUI-Manager
clone_repo https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes
clone_repo https://github.com/shiimizu/ComfyUI-TiledDiffusion
clone_repo https://github.com/Fannovel16/Stand-In-Preprocessor-ComfyUI
clone_repo https://github.com/Jorbit/comfy-plasma
clone_repo https://github.com/dazzlenodes/comfyui-dazzlenodes
clone_repo https://github.com/JamesWalker55/comfyui-various
clone_repo https://github.com/giriss/comfy-image-saver
clone_repo https://github.com/M1kep/ComfyLiterals
clone_repo https://github.com/eses-eses/ComfyUI-EsesImageResize
clone_repo https://github.com/lquesada/ComfyUI-AutoCropFaces
clone_repo https://github.com/GaiZhenbiao/ComfyUI-FlashVSR-Ultra-Fast
clone_repo https://github.com/M1kep/comfyui-tensorops
clone_repo https://github.com/kay-f/kaytool
for dir in */; do
    if [ -f "$dir/requirements.txt" ]; then
        echo "Installing requirements for $dir..."
        pip install -r "$dir/requirements.txt"
    fi
done

cd /apps/comfyui

TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

python3 /apps/comfyui/main.py --disable-xformers --listen 0.0.0.0 --port 3021 >/workspace/.logs/comfyui.log 2>&1 &

echo "COMFYUI: ComfyUI started"
echo "COMFYUI: Log file: /workspace/.logs/comfyui.log"
deactivate

