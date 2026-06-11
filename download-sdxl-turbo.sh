#!/bin/bash
#
# download-sdxl-turbo.sh — Downloads the SDXL-Turbo checkpoint
# (single ~6.9GB file, includes UNet+CLIP+VAE) for fast image
# generation on Apple Silicon (MPS).
#
# Why: FLUX.1-schnell is too large/slow on a 24GB Mac Mini's shared
# memory (~30 min/image). SDXL-Turbo runs in 1 step and typically
# takes 5-15 seconds on M4.
#
# Run with: bash download-sdxl-turbo.sh

set -e

COMFY_DIR="$HOME/ai-stack/comfyui"
CHECKPOINTS="$COMFY_DIR/models/checkpoints"
TOKEN_FILE="$HOME/ai-stack/.hf-token"

mkdir -p "$CHECKPOINTS"

if [ ! -d "$COMFY_DIR" ]; then
    echo "ERROR: ComfyUI not found at $COMFY_DIR"
    exit 1
fi

# Reuse cached HF token if present (same as FLUX downloader)
HEADER_ARGS=()
if [ -f "$TOKEN_FILE" ]; then
    HF_TOKEN=$(cat "$TOKEN_FILE")
    HEADER_ARGS=(--header="Authorization: Bearer ${HF_TOKEN}")
fi

echo "Downloading SDXL-Turbo checkpoint (~6.9GB)..."
wget -c "${HEADER_ARGS[@]}" \
    -O "$CHECKPOINTS/sd_xl_turbo_1.0_fp16.safetensors" \
    "https://huggingface.co/stabilityai/sdxl-turbo/resolve/main/sd_xl_turbo_1.0_fp16.safetensors?download=true"

echo ""
echo "Done. Restarting ComfyUI..."
launchctl kickstart -k "gui/$(id -u)/com.ruberte.comfyui" 2>/dev/null || \
    echo "(ComfyUI service not running as launchd job — restart manually)"

echo ""
echo "Next: import sdxl-turbo-workflow.json into ComfyUI, export as"
echo "API format, and upload to Open WebUI (see README Step 4b)."
