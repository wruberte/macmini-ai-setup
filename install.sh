#!/bin/bash
#
# install.sh — One-time setup for local AI stack on Mac Mini M4 (24GB)
# Components: Ollama (LLM), OrbStack (Docker), Open WebUI (chat/web UI),
#             ComfyUI (image generation)
#
# Run with: bash install.sh
# Safe to re-run — skips anything already installed.

set -e

STACK_DIR="$HOME/ai-stack"
COMFY_DIR="$STACK_DIR/comfyui"
LOG_DIR="$STACK_DIR/logs"
PLIST_DIR="$HOME/Library/LaunchAgents"

echo "=================================================="
echo "  AI Stack Installer — Mac Mini M4 24GB"
echo "=================================================="

mkdir -p "$STACK_DIR" "$LOG_DIR" "$PLIST_DIR"

# ------------------------------------------------------------------
# 1. Homebrew
# ------------------------------------------------------------------
if ! command -v brew &> /dev/null; then
    echo "[1/8] Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "[1/8] Homebrew already installed — skipping."
fi

# ------------------------------------------------------------------
# 2. Ollama (LLM runtime)
# ------------------------------------------------------------------
if ! command -v ollama &> /dev/null; then
    echo "[2/8] Installing Ollama..."
    brew install ollama
else
    echo "[2/8] Ollama already installed — skipping."
fi

echo "      Starting Ollama as a background service..."
brew services start ollama

# Give the service a moment to come up
sleep 3

# ------------------------------------------------------------------
# 3. Pull the LLM (8B abliterated — leaves headroom on 24GB)
# ------------------------------------------------------------------
echo "[3/8] Pulling LLM model (mannix/llama3.1-8b-abliterated:q5_K_M)..."
ollama pull mannix/llama3.1-8b-abliterated:q5_K_M

# ------------------------------------------------------------------
# 4. OrbStack (lightweight Docker runtime for Apple Silicon)
# ------------------------------------------------------------------
if ! command -v docker &> /dev/null; then
    echo "[4/8] Installing OrbStack (Docker runtime)..."
    brew install --cask orbstack
    echo "      >>> OrbStack installed. Launch it once manually to finish"
    echo "      >>> first-time setup, then re-run this script."
    open -a OrbStack
    exit 0
else
    echo "[4/8] Docker runtime already present — skipping."
fi

# ------------------------------------------------------------------
# 5. ComfyUI (image generation)
# ------------------------------------------------------------------
if [ ! -d "$COMFY_DIR" ]; then
    echo "[5/8] Cloning ComfyUI..."
    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR"

    echo "      Creating Python venv and installing dependencies (MPS/Apple Silicon)..."
    cd "$COMFY_DIR"
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install torch torchvision torchaudio
    pip install -r requirements.txt
    deactivate
else
    echo "[5/8] ComfyUI already cloned — skipping initial setup."
fi

mkdir -p "$COMFY_DIR/models/checkpoints" \
         "$COMFY_DIR/models/unet" \
         "$COMFY_DIR/models/vae" \
         "$COMFY_DIR/models/clip"

echo "      NOTE: FLUX.1-schnell model files are NOT auto-downloaded"
echo "      (large + license gated). See README.md Section 4 for"
echo "      manual download links and placement."

# ------------------------------------------------------------------
# 6. Open WebUI (web UI + mobile API) via Docker Compose
# ------------------------------------------------------------------
echo "[6/8] Setting up Open WebUI..."
cp "$(dirname "$0")/docker-compose.yml" "$STACK_DIR/docker-compose.yml"
cd "$STACK_DIR"
docker compose up -d

# ------------------------------------------------------------------
# 7. Install update script + LaunchAgents
# ------------------------------------------------------------------
echo "[7/8] Installing update script and launchd jobs..."
cp "$(dirname "$0")/update-ai-stack.sh" "$STACK_DIR/update-ai-stack.sh"
chmod +x "$STACK_DIR/update-ai-stack.sh"

cp "$(dirname "$0")/com.ruberte.ai-update.plist" "$PLIST_DIR/"
cp "$(dirname "$0")/com.ruberte.comfyui.plist" "$PLIST_DIR/"

# Replace placeholder $HOME paths in plists with actual home dir
sed -i '' "s|__HOME__|$HOME|g" "$PLIST_DIR/com.ruberte.ai-update.plist"
sed -i '' "s|__HOME__|$HOME|g" "$PLIST_DIR/com.ruberte.comfyui.plist"

launchctl unload "$PLIST_DIR/com.ruberte.ai-update.plist" 2>/dev/null || true
launchctl unload "$PLIST_DIR/com.ruberte.comfyui.plist" 2>/dev/null || true
launchctl load "$PLIST_DIR/com.ruberte.ai-update.plist"
launchctl load "$PLIST_DIR/com.ruberte.comfyui.plist"

# ------------------------------------------------------------------
# 8. Done
# ------------------------------------------------------------------
echo "[8/8] Done."
echo ""
echo "=================================================="
echo "  Setup complete!"
echo "--------------------------------------------------"
echo "  Open WebUI:  http://localhost:3000"
echo "  ComfyUI:     http://localhost:8188"
echo "  Ollama API:  http://localhost:11434"
echo ""
echo "  To update everything later, run:"
echo "    $STACK_DIR/update-ai-stack.sh"
echo "  (also runs automatically on every reboot)"
echo ""
echo "  Next steps: see README.md for"
echo "    - downloading the FLUX image model"
echo "    - configuring Open WebUI -> ComfyUI integration"
echo "    - mobile app setup (iOS/Android)"
echo "    - remote access (Tailscale)"
echo "=================================================="
