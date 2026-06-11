#!/bin/bash
#
# download-flux-models.sh — Downloads FLUX.1-schnell model files for
# ComfyUI using huggingface-cli, and places them in the correct
# ComfyUI model directories.
#
# Prerequisites:
#   1. Accept the FLUX.1-schnell license at:
#      https://huggingface.co/black-forest-labs/FLUX.1-schnell
#   2. Have a Hugging Face access token:
#      https://huggingface.co/settings/tokens
#
# Run with: bash download-flux-models.sh
# (will prompt for HF login on first run)

set -e

COMFY_DIR="$HOME/ai-stack/comfyui"
CHECKPOINTS="$COMFY_DIR/models/checkpoints"
UNET="$COMFY_DIR/models/unet"
VAE="$COMFY_DIR/models/vae"
CLIP="$COMFY_DIR/models/clip"

echo "=================================================="
echo "  FLUX.1-schnell Model Downloader"
echo "=================================================="

if [ ! -d "$COMFY_DIR" ]; then
    echo "ERROR: ComfyUI not found at $COMFY_DIR"
    echo "Run install.sh first."
    exit 1
fi

mkdir -p "$CHECKPOINTS" "$UNET" "$VAE" "$CLIP"

# ------------------------------------------------------------------
# Ensure huggingface-cli is available
# ------------------------------------------------------------------
if ! command -v huggingface-cli &> /dev/null; then
    echo "[1/3] Installing huggingface_hub CLI..."
    pip3 install --upgrade huggingface_hub
else
    echo "[1/3] huggingface-cli already installed — skipping."
fi

# ------------------------------------------------------------------
# Log in (only needed once — token is cached afterward)
# ------------------------------------------------------------------
if [ ! -f "$HOME/.cache/huggingface/token" ]; then
    echo ""
    echo "[2/3] Hugging Face login required."
    echo "      Generate a token (read access is enough) at:"
    echo "      https://huggingface.co/settings/tokens"
    echo "      Make sure you've accepted the license at:"
    echo "      https://huggingface.co/black-forest-labs/FLUX.1-schnell"
    echo ""
    huggingface-cli login
else
    echo "[2/3] Already logged in to Hugging Face — skipping."
fi

# ------------------------------------------------------------------
# Download files into a temp dir, then place into ComfyUI dirs
# ------------------------------------------------------------------
echo "[3/3] Downloading FLUX.1-schnell model files..."

TMP_DIR="$HOME/ai-stack/.flux-download-tmp"
mkdir -p "$TMP_DIR"

echo "  -> flux1-schnell.safetensors (~17GB, may take a while)"
huggingface-cli download black-forest-labs/FLUX.1-schnell \
    flux1-schnell.safetensors \
    --local-dir "$TMP_DIR"

echo "  -> ae.safetensors (VAE)"
huggingface-cli download black-forest-labs/FLUX.1-schnell \
    ae.safetensors \
    --local-dir "$TMP_DIR"

echo "  -> clip_l.safetensors"
huggingface-cli download comfyanonymous/flux_text_encoders \
    clip_l.safetensors \
    --local-dir "$TMP_DIR"

echo "  -> t5xxl_fp8_e4m3fn.safetensors (recommended for 24GB systems)"
huggingface-cli download comfyanonymous/flux_text_encoders \
    t5xxl_fp8_e4m3fn.safetensors \
    --local-dir "$TMP_DIR"

# ------------------------------------------------------------------
# Place into ComfyUI model directories
# ------------------------------------------------------------------
echo ""
echo "Placing model files into ComfyUI directories..."

# Main checkpoint -> both checkpoints/ and unet/ (symlinked)
cp "$TMP_DIR/flux1-schnell.safetensors" "$CHECKPOINTS/"
ln -sf "$CHECKPOINTS/flux1-schnell.safetensors" "$UNET/flux1-schnell.safetensors"

cp "$TMP_DIR/ae.safetensors" "$VAE/"
cp "$TMP_DIR/clip_l.safetensors" "$CLIP/"
cp "$TMP_DIR/t5xxl_fp8_e4m3fn.safetensors" "$CLIP/"

# Clean up temp download dir (files are now copied into place)
rm -rf "$TMP_DIR"

echo ""
echo "=================================================="
echo "  Done. Restarting ComfyUI to pick up new models..."
echo "=================================================="
launchctl kickstart -k "gui/$(id -u)/com.ruberte.comfyui" 2>/dev/null || \
    echo "  (ComfyUI service not running yet — start it manually if needed)"

echo ""
echo "Visit http://localhost:8188 and confirm the checkpoint, VAE,"
echo "and CLIP dropdowns now show the FLUX files."
