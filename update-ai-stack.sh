#!/bin/bash
#
# update-ai-stack.sh — Updates all components of the local AI stack.
# Run automatically on every boot (via launchd) or manually any time:
#   ~/ai-stack/update-ai-stack.sh
#
# Logs to ~/ai-stack/logs/update-YYYY-MM-DD.log

STACK_DIR="$HOME/ai-stack"
COMFY_DIR="$STACK_DIR/comfyui"
LOG_DIR="$STACK_DIR/logs"
LOG_FILE="$LOG_DIR/update-$(date +%Y-%m-%d).log"
MODEL="mannix/llama3.1-8b-abliterated:q5_K_M"

mkdir -p "$LOG_DIR"

# Make sure Homebrew + brew-installed tools (ollama, etc) are on PATH
# even when run non-interactively by launchd.
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

{
echo "===================================================="
echo "AI Stack update — $(date)"
echo "===================================================="

# --- 1. Update Ollama itself ---
echo ""
echo "--- [1/4] Updating Ollama ---"
brew update
brew upgrade ollama || echo "Ollama already up to date."
brew services restart ollama
sleep 3

# --- 2. Update the LLM model ---
echo ""
echo "--- [2/4] Updating LLM model: $MODEL ---"
ollama pull "$MODEL"

# --- 3. Update Open WebUI (Docker image + container) ---
echo ""
echo "--- [3/4] Updating Open WebUI ---"
cd "$STACK_DIR"
docker compose pull
docker compose up -d

# Optional: prune old/dangling images so disk doesn't fill up over time
docker image prune -f

# --- 4. Update ComfyUI (and its custom nodes, if any) ---
echo ""
echo "--- [4/4] Updating ComfyUI ---"
if [ -d "$COMFY_DIR" ]; then
    cd "$COMFY_DIR"
    git pull --rebase --autostash

    source venv/bin/activate
    pip install --upgrade -r requirements.txt

    # Update any custom nodes that are git repos
    if [ -d "custom_nodes" ]; then
        for d in custom_nodes/*/; do
            if [ -d "$d/.git" ]; then
                echo "  Updating custom node: $d"
                (cd "$d" && git pull --rebase --autostash)
                if [ -f "$d/requirements.txt" ]; then
                    pip install --upgrade -r "$d/requirements.txt"
                fi
            fi
        done
    fi
    deactivate

    # Restart ComfyUI service to pick up changes
    launchctl kickstart -k "gui/$(id -u)/com.ruberte.comfyui" 2>/dev/null || true
else
    echo "  ComfyUI directory not found — skipping."
fi

echo ""
echo "===================================================="
echo "Update complete — $(date)"
echo "===================================================="
} 2>&1 | tee -a "$LOG_FILE"

# Keep only the last 14 days of logs
find "$LOG_DIR" -name "update-*.log" -mtime +14 -delete
