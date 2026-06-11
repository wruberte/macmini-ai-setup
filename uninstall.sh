#!/bin/bash
#
# uninstall.sh — Removes the local AI stack (Ollama, Open WebUI, ComfyUI)
# and all launchd jobs/services installed by install.sh.
#
# Run with: bash uninstall.sh
#
# By default this leaves your downloaded models/checkpoints in place
# in case you want to reinstall later. Pass --purge to delete those too.

set -e

STACK_DIR="$HOME/ai-stack"
PLIST_DIR="$HOME/Library/LaunchAgents"
PURGE=false

if [ "$1" == "--purge" ]; then
    PURGE=true
fi

echo "=================================================="
echo "  AI Stack Uninstaller"
echo "=================================================="

# ------------------------------------------------------------------
# 1. Unload and remove launchd jobs
# ------------------------------------------------------------------
echo "[1/5] Removing launchd jobs..."
launchctl unload "$PLIST_DIR/com.ruberte.ai-update.plist" 2>/dev/null || true
launchctl unload "$PLIST_DIR/com.ruberte.comfyui.plist" 2>/dev/null || true
rm -f "$PLIST_DIR/com.ruberte.ai-update.plist"
rm -f "$PLIST_DIR/com.ruberte.comfyui.plist"

# ------------------------------------------------------------------
# 2. Stop and remove Open WebUI (Docker)
# ------------------------------------------------------------------
echo "[2/5] Removing Open WebUI container..."
if [ -f "$STACK_DIR/docker-compose.yml" ]; then
    cd "$STACK_DIR"
    docker compose down
    if [ "$PURGE" = true ]; then
        echo "      --purge: removing Open WebUI data volume..."
        docker volume rm ai-stack_open-webui-data 2>/dev/null || true
    fi
fi

# ------------------------------------------------------------------
# 3. Stop Ollama and remove model
# ------------------------------------------------------------------
echo "[3/5] Stopping Ollama..."
brew services stop ollama 2>/dev/null || true

if [ "$PURGE" = true ]; then
    echo "      --purge: removing pulled LLM model..."
    ollama rm mannix/llama3.1-8b-abliterated:q5_K_M 2>/dev/null || true
    echo "      --purge: uninstalling Ollama via Homebrew..."
    brew uninstall ollama 2>/dev/null || true
fi

# ------------------------------------------------------------------
# 4. Remove ComfyUI
# ------------------------------------------------------------------
echo "[4/5] Removing ComfyUI..."
if [ "$PURGE" = true ]; then
    rm -rf "$STACK_DIR/comfyui"
else
    echo "      (kept: $STACK_DIR/comfyui — includes downloaded models)"
    echo "      Re-run with --purge to delete it entirely."
fi

# ------------------------------------------------------------------
# 5. Remove stack directory (scripts, logs, compose file)
# ------------------------------------------------------------------
echo "[5/5] Cleaning up stack directory..."
if [ "$PURGE" = true ]; then
    rm -rf "$STACK_DIR"
    echo "      Removed $STACK_DIR entirely."
else
    rm -f "$STACK_DIR/docker-compose.yml" "$STACK_DIR/update-ai-stack.sh"
    rm -rf "$STACK_DIR/logs"
    echo "      Removed scripts and logs. ComfyUI + models kept under"
    echo "      $STACK_DIR/comfyui"
fi

echo ""
echo "=================================================="
echo "  Uninstall complete."
if [ "$PURGE" = false ]; then
    echo "  (Models and ComfyUI install were preserved."
    echo "   Run 'bash uninstall.sh --purge' to remove everything.)"
fi
echo "=================================================="
