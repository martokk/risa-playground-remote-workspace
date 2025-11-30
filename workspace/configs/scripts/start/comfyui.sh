#!/usr/bin/env bash
export PYTHONUNBUFFERED=1

echo "COMFYUI: Starting ComfyUI"

source /workspace/.cache/venvs/comfyui/bin/activate


cd /workspace/configs/comfyui/custom_nodes/
rm -rf ComfyUI-Manager ComfyUI_Comfyroll_CustomNodes ComfyUI-TiledDiffusion Stand-In_Preprocessor_ComfyUI comfy-plasma comfyui-dazzlenodes comfyui-various comfy-image-saver ComfyLiterals ComfyUI-EsesImageResize ComfyUI-AutoCropFaces ComfyUI-FlashVSR_Ultra_Fast IPAdapterWAN comfyui-tensorops kaytool
git clone https://github.com/ltdrdata/ComfyUI-Manager
git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes
git clone https://github.com/shiimizu/ComfyUI-TiledDiffusion
git clone https://github.com/Fannovel16/Stand-In-Preprocessor-ComfyUI
git clone https://github.com/Jorbit/comfy-plasma
git clone https://github.com/dazzlenodes/comfyui-dazzlenodes
git clone https://github.com/JamesWalker55/comfyui-various
git clone https://github.com/giriss/comfy-image-saver
git clone https://github.com/dionysius-s/ComfyLiterals
git clone https://github.com/eses-eses/ComfyUI-EsesImageResize
git clone https://github.com/lquesada/ComfyUI-AutoCropFaces
git clone https://github.com/GaiZhenbiao/ComfyUI-FlashVSR-Ultra-Fast
git clone https://github.com/M1kep/comfyui-tensorops
git clone https://github.com/kay-f/kaytool
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

