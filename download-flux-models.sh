#!/bin/bash
#
# download-flux-models.sh — Downloads FLUX.1-schnell model files for
# ComfyUI using wget + a Hugging Face access token, and places them
# in the correct ComfyUI model directories.
#
# Prerequisites:
#   1. Accept the FLUX.1-schnell license at:
#      https://huggingface.co/black-forest-labs/FLUX.1-schnell
#   2. Create a Hugging Face access token (read access is enough):
#      https://huggingface.co/settings/tokens
#
# Run with: bash download-flux-models.sh
# (will prompt for your HF token on first run and cache it locally)

set -e

COMFY_DIR="$HOME/ai-stack/comfyui"
CHECKPOINTS="$COMFY_DIR/models/checkpoints"
UNET="$COMFY_DIR/models/unet"
VAE="$COMFY_DIR/models/vae"
CLIP="$COMFY_DIR/models/clip"
TOKEN_FILE="$HOME/ai-stack/.hf-token"

echo "=================================================="
echo "  FLUX.1-schnell Model Downloader (wget)"
echo "=================================================="

if [ ! -d "$COMFY_DIR" ]; then
    echo "ERROR: ComfyUI not found at $COMFY_DIR"
    echo "Run install.sh first."
    exit 1
fi

mkdir -p "$CHECKPOINTS" "$UNET" "$VAE" "$CLIP"

# ------------------------------------------------------------------
# Get / cache Hugging Face token
# ------------------------------------------------------------------
if [ -f "$TOKEN_FILE" ]; then
    HF_TOKEN=$(cat "$TOKEN_FILE")
    echo "[1/2] Using cached Hugging Face token."
else
    echo "[1/2] Hugging Face token required (read access is enough)."
    echo "      Create one at: https://huggingface.co/settings/tokens"
    echo "      Make sure you've accepted the license at:"
    echo "      https://huggingface.co/black-forest-labs/FLUX.1-schnell"
    echo ""
    read -rsp "      Paste your HF token: " HF_TOKEN
    echo ""
    echo "$HF_TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
fi

# ------------------------------------------------------------------
# Download helper
# ------------------------------------------------------------------
download() {
    local repo="$1"
    local file="$2"
    local dest="$3"
    local url="https://huggingface.co/${repo}/resolve/main/${file}?download=true"

    echo "  -> ${file}"
    wget -c --header="Authorization: Bearer ${HF_TOKEN}" \
        -O "${dest}/${file}" \
        "${url}"
}

# ------------------------------------------------------------------
# Downloads
# ------------------------------------------------------------------
echo ""
echo "[2/2] Downloading FLUX.1-schnell model files (~20GB total)..."

download "black-forest-labs/FLUX.1-schnell" "flux1-schnell.safetensors" "$CHECKPOINTS"
download "black-forest-labs/FLUX.1-schnell" "ae.safetensors" "$VAE"
download "comfyanonymous/flux_text_encoders" "clip_l.safetensors" "$CLIP"
download "comfyanonymous/flux_text_encoders" "t5xxl_fp8_e4m3fn.safetensors" "$CLIP"

# Symlink the main checkpoint into models/unet/ as well
ln -sf "$CHECKPOINTS/flux1-schnell.safetensors" "$UNET/flux1-schnell.safetensors"

echo ""
echo "=================================================="
echo "  Done. Restarting ComfyUI to pick up new models..."
echo "=================================================="
launchctl kickstart -k "gui/$(id -u)/com.ruberte.comfyui" 2>/dev/null || \
    echo "  (ComfyUI service not running yet — start it manually if needed)"

echo ""
echo "Visit http://localhost:8188 and confirm the checkpoint, VAE,"
echo "and CLIP dropdowns now show the FLUX files."
echo ""
echo "Note: if any download above returned a small HTML/error file"
echo "instead of a multi-GB file, your token likely doesn't have"
echo "access yet — make sure you've accepted the FLUX.1-schnell"
echo "license while logged in as the same account that owns the token."
